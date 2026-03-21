import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permission_service.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called automatically when user returns from Android settings pages.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    if (!mounted) return;
    setState(() => _isChecking = true);
    await context.read<PermissionService>().checkAll();
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final permSvc = context.watch<PermissionService>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            _buildHeader(theme),

            // ── Permission Cards ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _PermissionCard(
                    icon: Icons.query_stats_rounded,
                    iconColor: const Color(0xFF7B61FF),
                    title: 'Usage Access',
                    description:
                        'Allows QuantumFocus to see which app is currently open on your screen. '
                        'This is how the blocking system knows when you try to open a restricted app '
                        'during a focus session.',
                    isGranted: permSvc.usageAccess,
                    isChecking: _isChecking,
                    onGrant: () =>
                        context.read<PermissionService>().openUsageAccessSettings(),
                  ),
                  const SizedBox(height: 16),
                  _PermissionCard(
                    icon: Icons.layers_rounded,
                    iconColor: const Color(0xFF00D4FF),
                    title: 'Draw Over Other Apps',
                    description:
                        'Lets QuantumFocus display the focus block screen on top of any other app. '
                        'Without this, we cannot prevent you from using restricted apps during '
                        'active study sessions.',
                    isGranted: permSvc.overlayPermission,
                    isChecking: _isChecking,
                    onGrant: () =>
                        context.read<PermissionService>().openOverlaySettings(),
                  ),
                  const SizedBox(height: 16),
                  _PermissionCard(
                    icon: Icons.accessibility_new_rounded,
                    iconColor: const Color(0xFF00E5A0),
                    title: 'Accessibility Service',
                    description:
                        'Detects app-switch events so QuantumFocus can react the moment a blocked app '
                        'is opened. We use this only to enforce your study schedule — '
                        'we never read your screen content or personal data.',
                    isGranted: permSvc.accessibilityEnabled,
                    isChecking: _isChecking,
                    onGrant: () => context
                        .read<PermissionService>()
                        .openAccessibilitySettings(),
                  ),
                  const SizedBox(height: 16),
                  _PermissionCard(
                    icon: Icons.battery_charging_full_rounded,
                    iconColor: const Color(0xFFFF9F43),
                    title: 'Background Service',
                    description:
                        'Keeps monitoring active even when QuantumFocus is minimised. '
                        'Also ensures the service automatically restarts if your device reboots '
                        'mid-session. This permission is granted automatically at install.',
                    isGranted: permSvc.backgroundGranted,
                    isChecking: false,
                    autoGranted: true,
                    onGrant: null,
                  ),
                  const SizedBox(height: 24),
                  _buildPrivacyNote(theme),
                ],
              ),
            ),

            // ── Continue Button ──────────────────────────────────────────
            _buildContinueButton(context, permSvc),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7B61FF).withValues(alpha: 0.15),
            const Color(0xFF0A0A14),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shield icon with glow
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'App Blocking Setup',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'QuantumFocus needs a few special permissions to block distracting apps '
            'during your study sessions. These are one-time settings — tap each one to grant.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy Note ────────────────────────────────────────────────────────

  Widget _buildPrivacyNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 18, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your privacy is protected. QuantumFocus uses these permissions '
              'exclusively for focus enforcement. We never read your personal data, '
              'messages, or screen content.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Continue Button ─────────────────────────────────────────────────────

  Widget _buildContinueButton(BuildContext context, PermissionService permSvc) {
    final allGranted = permSvc.allGranted;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A14),
        border: Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!allGranted)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_grantedCount(permSvc)}/3 permissions granted',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: allGranted
                    ? const LinearGradient(
                        colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)],
                      )
                    : null,
                color: allGranted ? null : const Color(0xFF1A1A2E),
                boxShadow: allGranted
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7B61FF).withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton(
                onPressed: allGranted
                    ? () => Navigator.of(context)
                        .pushReplacementNamed('/dashboard')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: allGranted ? Colors.white : Colors.white30,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      allGranted ? 'Continue to QuantumFocus' : 'Grant All Permissions First',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (allGranted) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _grantedCount(PermissionService p) {
    int count = 0;
    if (p.usageAccess) count++;
    if (p.overlayPermission) count++;
    if (p.accessibilityEnabled) count++;
    return count;
  }
}

// ── Permission Card Widget ──────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isGranted;
  final bool isChecking;
  final bool autoGranted;
  final VoidCallback? onGrant;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.isChecking,
    this.autoGranted = false,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF00E5A0).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: isGranted
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5A0).withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header Row ─────────────────────────────────────────
            Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Title and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusBadge(),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Description ──────────────────────────────────────────────
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                height: 1.55,
              ),
            ),

            // ── Grant Button ─────────────────────────────────────────────
            if (!isGranted && !autoGranted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onGrant,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Grant Permission'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: iconColor,
                    side: BorderSide(color: iconColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (isChecking) {
      return Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white38,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Checking…',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      );
    }

    if (isGranted) {
      return Row(
        children: const [
          Icon(Icons.check_circle_rounded,
              size: 13, color: Color(0xFF00E5A0)),
          SizedBox(width: 4),
          Text(
            'Granted',
            style: TextStyle(
              color: Color(0xFF00E5A0),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Row(
      children: const [
        Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFFF9F43)),
        SizedBox(width: 4),
        Text(
          'Required',
          style: TextStyle(
            color: Color(0xFFFF9F43),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
