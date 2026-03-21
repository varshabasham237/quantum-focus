import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_blocking_model.dart';
import 'api_service.dart';

/// Manages the app blocking session, blocklist, and Mode Switching Control (5.3).
///
/// Mode Switching Rules:
///  - Max [maxSwitches] = 3 mode-off/on toggles per session
///  - After 3 switches → [focusLocked] = true → cannot turn off focus mode
///  - Unlocks automatically when the session ends
class AppBlockingService extends ChangeNotifier {
  static const _channel = MethodChannel('com.quantumfocus/permissions');

  // ── SharedPreferences keys (must match FocusAccessibilityService.kt) ───
  static const _keyBlocklist      = 'blocked_packages';
  static const _keySessionActive  = 'session_active';
  static const _keySessionEndMs   = 'session_end_ms';
  static const _keySwitchCount    = 'switch_count';
  static const _keyFocusLocked    = 'focus_locked';

  static const int maxSwitches = 3;

  final ApiService _api;
  AppBlockingService(this._api);

  // ── State ──────────────────────────────────────────────────────────────
  List<BlockedApp>   _blocklist      = [];
  List<InstalledApp> _installedApps  = [];
  bool _sessionActive = false;
  int  _sessionEndMs  = 0;
  bool _isLoading     = false;
  int  _switchCount   = 0;       // # of off→on / on→off toggles this session
  bool _focusLocked   = false;   // locked after maxSwitches reached

  List<BlockedApp>   get blocklist      => _blocklist;
  List<InstalledApp> get installedApps  => _installedApps;
  bool get sessionActive  => _sessionActive;
  bool get isLoading      => _isLoading;
  int  get switchCount    => _switchCount;
  bool get focusLocked    => _focusLocked;
  int  get switchesLeft   => (maxSwitches - _switchCount).clamp(0, maxSwitches);
  bool get canToggle      => !_focusLocked;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  DateTime? get sessionEndTime =>
      _sessionEndMs > 0 ? DateTime.fromMillisecondsSinceEpoch(_sessionEndMs) : null;

  // ── Init ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    await fetchBlocklist();
    await _syncSessionStateFromPrefs();
    if (isAndroid) await fetchInstalledApps();
  }

  // ── Blocklist ───────────────────────────────────────────────────────────

  Future<void> fetchBlocklist() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.getList('/app-blocking/blocklist');
      if (data != null) {
        _blocklist = data
            .map((e) => BlockedApp.fromJson(e as Map<String, dynamic>))
            .toList();
        await _writeBlocklistToPrefs();
      }
    } catch (_) {
      await _readBlocklistFromPrefs();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addApp(InstalledApp app) async {
    try {
      await _api.post('/app-blocking/blocklist', {
        'package_name': app.packageName,
        'app_name': app.appName,
      });
      _blocklist.add(BlockedApp(packageName: app.packageName, appName: app.appName));
      await _writeBlocklistToPrefs();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeApp(String packageName) async {
    try {
      await _api.delete('/app-blocking/blocklist/$packageName');
      _blocklist.removeWhere((a) => a.packageName == packageName);
      await _writeBlocklistToPrefs();
      notifyListeners();
    } catch (_) {}
  }

  bool isBlocked(String packageName) =>
      _blocklist.any((a) => a.packageName == packageName);

  // ── Session ──────────────────────────────────────────────────────────────

  Future<void> startSession({required int durationMinutes}) async {
    final endMs = DateTime.now()
        .add(Duration(minutes: durationMinutes))
        .millisecondsSinceEpoch;
    try {
      await _api.post('/app-blocking/session/start',
          {'duration_minutes': durationMinutes});
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, true);
    await prefs.setInt(_keySessionEndMs, endMs);
    // Reset switch counter on fresh session start
    await prefs.setInt(_keySwitchCount, 0);
    await prefs.setBool(_keyFocusLocked, false);

    if (isAndroid) {
      try { await _channel.invokeMethod('startMonitorService'); } catch (_) {}
    }

    _sessionActive = true;
    _sessionEndMs  = endMs;
    _switchCount   = 0;
    _focusLocked   = false;
    notifyListeners();
  }

  /// Toggle focus mode on/off (respecting switch-count rules).
  ///
  /// Returns `false` (with reason) if locked and cannot toggle.
  Future<({bool success, String? reason})> toggleFocusMode() async {
    if (_focusLocked) {
      return (success: false, reason: 'Focus mode is locked after $_switchCount switches. Unlocks when session ends.');
    }

    if (!_sessionActive) {
      return (success: false, reason: 'No active focus session.');
    }

    // Count this switch
    _switchCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySwitchCount, _switchCount);

    // Check if we just hit the limit
    if (_switchCount >= maxSwitches) {
      _focusLocked = true;
      // Re-enable session-active (can't turn off once locked)
      await prefs.setBool(_keyFocusLocked, true);
      await prefs.setBool(_keySessionActive, true);

      if (isAndroid) {
        try { await _channel.invokeMethod('startMonitorService'); } catch (_) {}
      }

      notifyListeners();
      return (
        success: true,
        reason: '⚠️ Focus mode locked! You\'ve used all $maxSwitches switches. Stay focused until the session ends.'
      );
    }

    // Normal toggle — pause/resume blocking
    _sessionActive = !_sessionActive;
    await prefs.setBool(_keySessionActive, _sessionActive);

    if (_sessionActive) {
      if (isAndroid) {
        try { await _channel.invokeMethod('startMonitorService'); } catch (_) {}
      }
    } else {
      if (isAndroid) {
        try { await _channel.invokeMethod('stopMonitorService'); } catch (_) {}
      }
    }

    notifyListeners();
    return (
      success: true,
      reason: _sessionActive
          ? 'Focus mode resumed. $switchesLeft switch${switchesLeft == 1 ? "" : "es"} remaining.'
          : 'Focus mode paused. $switchesLeft switch${switchesLeft == 1 ? "" : "es"} remaining.'
    );
  }

  Future<void> stopSession() async {
    try {
      await _api.post('/app-blocking/session/stop', {});
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, false);
    await prefs.setInt(_keySessionEndMs, 0);
    await prefs.setInt(_keySwitchCount, 0);
    await prefs.setBool(_keyFocusLocked, false);

    if (isAndroid) {
      try { await _channel.invokeMethod('stopMonitorService'); } catch (_) {}
    }

    _sessionActive = false;
    _sessionEndMs  = 0;
    _switchCount   = 0;
    _focusLocked   = false;
    notifyListeners();
  }

  Future<void> _syncSessionStateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionActive = prefs.getBool(_keySessionActive) ?? false;
    _sessionEndMs  = prefs.getInt(_keySessionEndMs)   ?? 0;
    _switchCount   = prefs.getInt(_keySwitchCount)    ?? 0;
    _focusLocked   = prefs.getBool(_keyFocusLocked)   ?? false;

    // Auto-clear expired session
    if (_sessionEndMs > 0 &&
        DateTime.now().millisecondsSinceEpoch > _sessionEndMs) {
      _sessionActive = false;
      _sessionEndMs  = 0;
      _switchCount   = 0;
      _focusLocked   = false;
      await prefs.setBool(_keySessionActive, false);
      await prefs.setInt(_keySwitchCount, 0);
      await prefs.setBool(_keyFocusLocked, false);
    }
    notifyListeners();
  }

  // ── Installed Apps (via Kotlin) ─────────────────────────────────────────

  Future<void> fetchInstalledApps() async {
    if (!isAndroid) return;
    try {
      final result = await _channel.invokeMethod<List>('getInstalledApps');
      if (result != null) {
        _installedApps = result.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return InstalledApp(
            packageName: m['package_name'] as String,
            appName: m['app_name'] as String,
          );
        }).toList()
          ..sort((a, b) => a.appName.compareTo(b.appName));
      }
    } on PlatformException {
      _installedApps = [];
    }
    notifyListeners();
  }

  // ── SharedPreferences sync ──────────────────────────────────────────────

  Future<void> _writeBlocklistToPrefs() async {
    final packages = _blocklist.map((a) => a.packageName).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBlocklist, jsonEncode(packages));
  }

  Future<void> _readBlocklistFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBlocklist) ?? '[]';
    try {
      final packages = jsonDecode(raw) as List;
      _blocklist = packages
          .map((p) => BlockedApp(packageName: p as String, appName: p))
          .toList();
    } catch (_) {
      _blocklist = [];
    }
  }
}
