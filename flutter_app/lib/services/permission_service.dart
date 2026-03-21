import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';

/// Manages the four special Android permissions needed for App Blocking.
/// Uses a Kotlin MethodChannel for permissions that Flutter can't check natively.
class PermissionService extends ChangeNotifier {
  static const _channel = MethodChannel('com.quantumfocus/permissions');

  // ── Permission States ────────────────────────────────────────────────────
  bool _usageAccess = false;
  bool _overlayPermission = false;
  bool _accessibilityEnabled = false;
  // Background/Boot is declared-only → always granted after install.
  final bool _backgroundGranted = true;

  bool get usageAccess => _usageAccess;
  bool get overlayPermission => _overlayPermission;
  bool get accessibilityEnabled => _accessibilityEnabled;
  bool get backgroundGranted => _backgroundGranted;

  /// True only when all three user-facing permissions are granted.
  bool get allGranted =>
      _usageAccess && _overlayPermission && _accessibilityEnabled;

  /// True when this is running on Android (the only supported platform).
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  // ── Check All ────────────────────────────────────────────────────────────

  /// Re-checks all permissions and notifies listeners.
  /// Call this on app resume (e.g., when user returns from settings).
  Future<void> checkAll() async {
    if (!isAndroid) {
      // On non-Android platforms, simulate all granted so the gate doesn't block.
      _usageAccess = true;
      _overlayPermission = true;
      _accessibilityEnabled = true;
      notifyListeners();
      return;
    }

    await Future.wait([
      _checkUsageAccess(),
      _checkOverlay(),
      _checkAccessibility(),
    ]);
    notifyListeners();
  }

  Future<void> _checkUsageAccess() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkUsageAccess');
      _usageAccess = result ?? false;
    } on PlatformException {
      _usageAccess = false;
    }
  }

  Future<void> _checkOverlay() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('checkOverlayPermission');
      _overlayPermission = result ?? false;
    } on PlatformException {
      _overlayPermission = false;
    }
  }

  Future<void> _checkAccessibility() async {
    try {
      // Checks the accessibility service that will be created in Module 5.2.
      final result = await _channel.invokeMethod<bool>(
        'checkAccessibilityEnabled',
        {
          'serviceClass':
              'com.antidistraction.anti_distraction_app/.FocusAccessibilityService',
        },
      );
      _accessibilityEnabled = result ?? false;
    } on PlatformException {
      _accessibilityEnabled = false;
    }
  }

  // ── Deep-Link Openers ───────────────────────────────────────────────────

  /// Opens Android's Usage Access settings page via Kotlin channel.
  Future<void> openUsageAccessSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {
      // Fallback to generic app settings
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
    }
  }

  /// Opens the Draw-Over-Other-Apps (Overlay) settings via Kotlin channel.
  Future<void> openOverlaySettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (_) {
      await AppSettings.openAppSettings(type: AppSettingsType.security);
    }
  }

  /// Opens the Accessibility settings page.
  Future<void> openAccessibilitySettings() async {
    if (!isAndroid) return;
    await AppSettings.openAppSettings(type: AppSettingsType.accessibility);
  }
}
