import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import '../services/strictness_service.dart';
import 'package:intl/intl.dart';

/// Main Focus Screen — timer + controls + focus state display
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  // Timer state
  int _focusDuration = 25 * 60; // 25 minutes in seconds
  int _remainingTime = 25 * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  int _completedSessions = 0;
  Timer? _timer;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _checkStrictness();
  }
  
  Future<void> _checkStrictness() async {
    final strictnessService = StrictnessService(ApiService());
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final status = await strictnessService.evaluateToday(todayStr);
    
    if (status != null && status.warnings > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Strictness Alert: You have ${status.warnings}/3 warnings. Keep your focus up!'),
          backgroundColor: AppTheme.accentRose,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/strictness'),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() => _remainingTime--);
      } else {
        _timer?.cancel();
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingTime = _focusDuration;
      _isBreak = false;
    });
  }

  void _onTimerComplete() {
    if (!_isBreak) {
      setState(() {
        _completedSessions++;
        _isBreak = true;
        _remainingTime = 5 * 60; // 5 min break
        _isRunning = false;
      });
    } else {
      setState(() {
        _isBreak = false;
        _remainingTime = _focusDuration;
        _isRunning = false;
      });
    }
  }

  String get _timeString {
    int minutes = _remainingTime ~/ 60;
    int seconds = _remainingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = _isBreak ? 5 * 60 : _focusDuration;
    return 1.0 - (_remainingTime / total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(_isBreak ? 'Break Time' : 'Focus Session'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_rounded, size: 22),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Session counter
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, size: 16, color: AppTheme.accentAmber),
                const SizedBox(width: 4),
                Text(
                  '$_completedSessions',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Focus State Label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: (_isBreak
                          ? AppTheme.accentEmerald
                          : _isRunning
                              ? AppTheme.accentViolet
                              : AppTheme.textMuted)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_isBreak
                            ? AppTheme.accentEmerald
                            : _isRunning
                                ? AppTheme.accentViolet
                                : AppTheme.textMuted)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _isBreak
                      ? '☕ Break Time'
                      : _isRunning
                          ? '🧠 Deep Focus'
                          : '⏳ Ready',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Circular Timer
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isRunning ? 1.0 + (_pulseController.value * 0.02) : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: _buildTimerRing(),
                  );
                },
              ),
              const SizedBox(height: 48),

              // Controls
              _buildControls(),
              const SizedBox(height: 40),

              // Duration Presets
              _buildDurationPresets(),
              const SizedBox(height: 24),

              // Session Stats
              _buildSessionStats(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerRing() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 260,
            height: 260,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              color: AppTheme.bgCard,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Progress ring
          SizedBox(
            width: 260,
            height: 260,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isBreak ? AppTheme.accentEmerald : AppTheme.accentViolet,
              ),
            ),
          ),
          // Glow effect
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bgSecondary,
              boxShadow: _isRunning
                  ? [
                      BoxShadow(
                        color: (_isBreak ? AppTheme.accentEmerald : AppTheme.accentViolet)
                            .withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Time
                Text(
                  _timeString,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w200,
                    color: AppTheme.textPrimary,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBreak ? 'BREAK' : 'FOCUS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isBreak ? AppTheme.accentEmerald : AppTheme.accentViolet,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset
        _buildControlBtn(
          icon: Icons.refresh_rounded,
          color: AppTheme.textMuted,
          size: 48,
          onTap: _resetTimer,
        ),
        const SizedBox(width: 24),

        // Play/Pause
        GestureDetector(
          onTap: _isRunning ? _pauseTimer : _startTimer,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isBreak
                  ? const LinearGradient(colors: [AppTheme.accentEmerald, Color(0xFF10B981)])
                  : AppTheme.gradientPrimary,
              boxShadow: [
                BoxShadow(
                  color: (_isBreak ? AppTheme.accentEmerald : AppTheme.accentViolet)
                      .withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Skip
        _buildControlBtn(
          icon: Icons.skip_next_rounded,
          color: AppTheme.textMuted,
          size: 48,
          onTap: () {
            _timer?.cancel();
            _onTimerComplete();
          },
        ),
      ],
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.bgCard,
          border: Border.all(color: AppTheme.bgInput),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }

  Widget _buildDurationPresets() {
    final presets = [15, 25, 45, 60];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: presets.map((min) {
        final isSelected = _focusDuration == min * 60 && !_isBreak;
        return GestureDetector(
          onTap: _isRunning
              ? null
              : () {
                  setState(() {
                    _focusDuration = min * 60;
                    _remainingTime = min * 60;
                    _isBreak = false;
                  });
                },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentViolet.withValues(alpha: 0.2) : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.accentViolet : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              '${min}m',
              style: TextStyle(
                color: isSelected ? AppTheme.accentViolet : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bgInput),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Sessions', '$_completedSessions', Icons.check_circle_outline, AppTheme.accentEmerald),
          Container(width: 1, height: 36, color: AppTheme.bgInput),
          _buildStatItem('Focus', '${(_completedSessions * _focusDuration ~/ 60)}m', Icons.schedule, AppTheme.accentViolet),
          Container(width: 1, height: 36, color: AppTheme.bgInput),
          _buildStatItem('Streak', '0 🔥', Icons.local_fire_department, AppTheme.accentAmber),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}
