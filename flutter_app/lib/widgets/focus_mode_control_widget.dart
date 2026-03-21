import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocking_service.dart';

/// FocusModeControlWidget
///
/// Displays the current focus mode state, remaining switch count,
/// and a toggle button with lock enforcement (Module 5.3).
///
/// Drop this anywhere in the Dashboard or session screen.
class FocusModeControlWidget extends StatefulWidget {
  /// Called when the session is ended by the user.
  final VoidCallback? onSessionEnd;

  const FocusModeControlWidget({super.key, this.onSessionEnd});

  @override
  State<FocusModeControlWidget> createState() => _FocusModeControlWidgetState();
}

class _FocusModeControlWidgetState extends State<FocusModeControlWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleToggle(AppBlockingService svc) async {
    if (svc.focusLocked) {
      // Shake & show lock message
      _shakeController.forward(from: 0);
      _showLockedSnackbar();
      return;
    }

    final result = await svc.toggleFocusMode();
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.reason ?? 'Cannot toggle focus mode.'),
          backgroundColor: const Color(0xFFFF4757),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (result.reason != null) {
      final isLockMessage = result.reason!.contains('locked');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isLockMessage ? Icons.lock_rounded : Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(result.reason!,
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          backgroundColor:
              isLockMessage ? const Color(0xFFFF4757) : const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isLockMessage ? 5 : 2),
        ),
      );
    }
  }

  void _showLockedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Focus mode is locked. You\'ve used all 3 switches. Complete the session to unlock.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AppBlockingService>();
    if (!svc.sessionActive && !svc.focusLocked) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (ctx, child) {
        final shake = (_shakeAnim.value * 12 * 
            (1 - _shakeAnim.value)).clamp(-8.0, 8.0);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: svc.focusLocked
                ? [
                    const Color(0xFFFF4757).withValues(alpha: 0.15),
                    const Color(0xFF1A1A2E),
                  ]
                : svc.sessionActive
                    ? [
                        const Color(0xFF7B61FF).withValues(alpha: 0.15),
                        const Color(0xFF1A1A2E),
                      ]
                    : [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF1A1A2E),
                      ],
          ),
          border: Border.all(
            color: svc.focusLocked
                ? const Color(0xFFFF4757).withValues(alpha: 0.5)
                : svc.sessionActive
                    ? const Color(0xFF7B61FF).withValues(alpha: 0.4)
                    : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildStatusIcon(svc),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusText(svc)),
                  _buildToggleBtn(svc),
                ],
              ),

              const SizedBox(height: 16),

              // Switch counter bar
              _buildSwitchCounter(svc),

              if (svc.focusLocked) ...[
                const SizedBox(height: 12),
                _buildLockWarning(svc),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Status icon ────────────────────────────────────────────────────────

  Widget _buildStatusIcon(AppBlockingService svc) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: svc.focusLocked
            ? const Color(0xFFFF4757).withValues(alpha: 0.15)
            : svc.sessionActive
                ? const Color(0xFF7B61FF).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: svc.focusLocked
              ? const Color(0xFFFF4757).withValues(alpha: 0.5)
              : svc.sessionActive
                  ? const Color(0xFF7B61FF).withValues(alpha: 0.5)
                  : Colors.white12,
        ),
      ),
      child: Icon(
        svc.focusLocked
            ? Icons.lock_rounded
            : svc.sessionActive
                ? Icons.shield_rounded
                : Icons.shield_outlined,
        color: svc.focusLocked
            ? const Color(0xFFFF4757)
            : svc.sessionActive
                ? const Color(0xFF7B61FF)
                : Colors.white38,
        size: 22,
      ),
    );
  }

  // ── Status text ────────────────────────────────────────────────────────

  Widget _buildStatusText(AppBlockingService svc) {
    final title = svc.focusLocked
        ? 'Focus Locked 🔒'
        : svc.sessionActive
            ? 'Focus Mode Active'
            : 'Focus Mode Paused';

    final subtitle = svc.focusLocked
        ? 'All switches used — blocking enforced until session ends'
        : svc.sessionActive
            ? 'Blocked apps are restricted'
            : 'Blocked apps are temporarily allowed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: svc.focusLocked
                ? const Color(0xFFFF4757)
                : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  // ── Toggle button ──────────────────────────────────────────────────────

  Widget _buildToggleBtn(AppBlockingService svc) {
    return GestureDetector(
      onTap: () => _handleToggle(svc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: svc.focusLocked
              ? const Color(0xFFFF4757).withValues(alpha: 0.2)
              : svc.sessionActive
                  ? const Color(0xFF7B61FF).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: svc.focusLocked
                ? const Color(0xFFFF4757).withValues(alpha: 0.6)
                : svc.sessionActive
                    ? const Color(0xFF7B61FF).withValues(alpha: 0.5)
                    : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              svc.focusLocked
                  ? Icons.lock_rounded
                  : svc.sessionActive
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
              size: 14,
              color: svc.focusLocked
                  ? const Color(0xFFFF4757)
                  : svc.sessionActive
                      ? const Color(0xFF7B61FF)
                      : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              svc.focusLocked
                  ? 'Locked'
                  : svc.sessionActive
                      ? 'Pause'
                      : 'Resume',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: svc.focusLocked
                    ? const Color(0xFFFF4757)
                    : svc.sessionActive
                        ? const Color(0xFF7B61FF)
                        : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Switch counter ─────────────────────────────────────────────────────

  Widget _buildSwitchCounter(AppBlockingService svc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mode switches used this session',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            Text(
              '${svc.switchCount} / ${AppBlockingService.maxSwitches}',
              style: TextStyle(
                color: svc.focusLocked
                    ? const Color(0xFFFF4757)
                    : svc.switchCount >= 2
                        ? const Color(0xFFFF9F43)
                        : const Color(0xFF00E5A0),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Visual indicator dots
        Row(
          children: List.generate(AppBlockingService.maxSwitches, (i) {
            final used = i < svc.switchCount;
            final isLast = i == AppBlockingService.maxSwitches - 1;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: used
                            ? (svc.focusLocked
                                ? const Color(0xFFFF4757)
                                : isLast
                                    ? const Color(0xFFFF9F43)
                                    : const Color(0xFF7B61FF))
                            : Colors.white12,
                        boxShadow: used
                            ? [
                                BoxShadow(
                                  color: (svc.focusLocked
                                          ? const Color(0xFFFF4757)
                                          : const Color(0xFF7B61FF))
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                )
                              ]
                            : [],
                      ),
                    ),
                  ),
                  if (!isLast) const SizedBox(width: 6),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Lock Warning ───────────────────────────────────────────────────────

  Widget _buildLockWarning(AppBlockingService svc) {
    final endTime = svc.sessionEndTime;
    final timeStr = endTime != null
        ? 'Unlocks at ${_formatTime(endTime)}'
        : 'Unlocks when session ends';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4757).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFF4757).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Color(0xFFFF9F43)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You\'ve used all 3 switches. Focus mode is enforced. $timeStr.',
                  style: const TextStyle(
                    color: Color(0xFFFF9F43),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _handleEmergencyExit(svc),
            icon: const Icon(Icons.emergency_share_rounded, size: 14),
            label: const Text('Use Emergency Exit', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF4757),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleEmergencyExit(AppBlockingService svc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFFF4757)),
            SizedBox(width: 8),
            Text('Emergency Exit', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure? This will consume your 1 daily emergency exit, instantly end your session, and ADD A WARNING to your Strictness Profile.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4757)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await svc.triggerEmergencyExit();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.reason ?? (res.success ? 'Emergency exit applied.' : 'Failed to exit.')),
          backgroundColor: res.success ? const Color(0xFFFF9F43) : const Color(0xFFFF4757),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      if (res.success && widget.onSessionEnd != null) {
        widget.onSessionEnd!();
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
