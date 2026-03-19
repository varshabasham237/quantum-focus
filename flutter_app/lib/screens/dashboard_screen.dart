import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import '../services/strictness_service.dart';
import '../services/planner_service.dart';
import '../models/planner_model.dart';

/// Main Focus Screen — timer + controls + mode picker + daily session timeline
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  // Session State
  bool _isLoading = true;
  DailySession? _dailySession;
  PlanMode _selectedMode = PlanMode.medium;
  int _currentBlockIndex = 0;

  // Timer state
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
    _loadDailySession();
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

  Future<void> _loadDailySession() async {
    setState(() => _isLoading = true);
    final plannerService = PlannerService(ApiService());
    final session = await plannerService.getDailySession();
    if (session != null && session.locked) {
      _setupLockedSession(session);
    } else {
      setState(() {
        _isLoading = false;
        // Default timer if no session locked yet
        _remainingTime = 25 * 60;
      });
    }
  }

  void _setupLockedSession(DailySession session) {
    setState(() {
      _dailySession = session;
      _currentBlockIndex = 0;
      _isLoading = false;
      _initCurrentBlock();
    });
  }

  void _initCurrentBlock() {
    if (_dailySession == null || _currentBlockIndex >= _dailySession!.blocks.length) return;
    final block = _dailySession!.blocks[_currentBlockIndex];
    _remainingTime = block.durationMin * 60;
    _isBreak = block.isBreak || block.isFree;
    _isRunning = false;
  }

  Future<void> _lockSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: const Text('Lock Daily Session?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to lock the ${_selectedMode.label} session for today? '
          'Once locked, you cannot change today\'s schedule.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Lock', style: TextStyle(color: AppTheme.accentViolet)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      final plannerService = PlannerService(ApiService());
      final lockedSession = await plannerService.lockDailySession(_selectedMode);
      if (lockedSession != null) {
        _setupLockedSession(lockedSession);
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to lock session. Check your profile.')),
          );
        }
      }
    }
  }

  Future<void> _editTask(int index, PlanBlock block) async {
    if (!block.isStudy) return;

    final controller = TextEditingController(text: block.task ?? '');
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text('Edit Task for ${block.displaySubject}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Read chapter 3',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.bgInput)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentViolet)),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppTheme.accentViolet)),
          ),
        ],
      ),
    );

    if (submitted != null && mounted) {
      final plannerService = PlannerService(ApiService());
      final success = await plannerService.updateDailySessionTask(index, submitted);
      if (success) {
        // Quiet reload
        final session = await plannerService.getDailySession();
        if (session != null && mounted) {
           setState(() {
             _dailySession = session;
           });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save task')),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_dailySession != null && _currentBlockIndex >= _dailySession!.blocks.length) return;
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
      if (_dailySession != null) {
        _initCurrentBlock();
      } else {
        _isRunning = false;
        _remainingTime = 25 * 60;
        _isBreak = false;
      }
    });
  }

  void _onTimerComplete() {
    if (_dailySession != null) {
      final block = _dailySession!.blocks[_currentBlockIndex];
      if (block.isStudy) _completedSessions++;

      if (_currentBlockIndex < _dailySession!.blocks.length - 1) {
        setState(() {
          _currentBlockIndex++;
          _initCurrentBlock();
        });
      } else {
        // Day complete
        setState(() {
          _currentBlockIndex++; // Move past the end
          _remainingTime = 0;
          _isRunning = false;
        });
      }
    } else {
      // Fallback behavior if no session
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
          _remainingTime = 25 * 60;
          _isRunning = false;
        });
      }
    }
  }

  String get _timeString {
    int minutes = _remainingTime ~/ 60;
    int seconds = _remainingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_dailySession != null) {
      if (_currentBlockIndex >= _dailySession!.blocks.length) return 1.0;
      final total = _dailySession!.blocks[_currentBlockIndex].durationMin * 60;
      return 1.0 - (_remainingTime / total);
    }
    final total = _isBreak ? 5 * 60 : 25 * 60;
    return 1.0 - (_remainingTime / total);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentViolet)),
      );
    }

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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // State Label
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
                  _dailySession != null && _currentBlockIndex >= _dailySession!.blocks.length
                      ? '🎉 Session Complete'
                      : _isBreak
                          ? '☕ Break'
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
              const SizedBox(height: 40),

              _buildControls(),
              const SizedBox(height: 40),

              if (_dailySession == null) _buildModePicker(),
              if (_dailySession != null) _buildSessionTimeline(),
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
          SizedBox(
            width: 260,
            height: 260,
            child: CircularProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isBreak ? AppTheme.accentEmerald : AppTheme.accentViolet,
              ),
            ),
          ),
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
                  _dailySession != null
                      ? (_currentBlockIndex < _dailySession!.blocks.length
                          ? _dailySession!.blocks[_currentBlockIndex].displaySubject.toUpperCase()
                          : 'DONE')
                      : (_isBreak ? 'BREAK' : 'FOCUS'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isBreak ? AppTheme.accentEmerald : AppTheme.accentViolet,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isDone = _dailySession != null && _currentBlockIndex >= _dailySession!.blocks.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlBtn(
          icon: Icons.refresh_rounded,
          color: AppTheme.textMuted,
          size: 48,
          onTap: isDone ? () {} : _resetTimer,
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: isDone ? null : (_isRunning ? _pauseTimer : _startTimer),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDone
                  ? const LinearGradient(colors: [AppTheme.bgInput, AppTheme.bgInput])
                  : (_isBreak
                      ? const LinearGradient(colors: [AppTheme.accentEmerald, Color(0xFF10B981)])
                      : AppTheme.gradientPrimary),
              boxShadow: isDone
                  ? []
                  : [
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
              color: isDone ? AppTheme.textMuted : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 24),
        _buildControlBtn(
          icon: Icons.skip_next_rounded,
          color: AppTheme.textMuted,
          size: 48,
          onTap: isDone
              ? () {}
              : () {
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

  Widget _buildModePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Today\'s Focus Mode',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: PlanMode.values.map((mode) {
            final isSelected = _selectedMode == mode;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMode = mode),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentViolet.withValues(alpha: 0.15) : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.accentViolet : AppTheme.bgInput,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(mode.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        mode.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? AppTheme.accentViolet : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _lockSession,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentViolet,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Confirm & Lock Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSessionTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_dailySession!.mode.label} Session',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgInput,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 14, color: AppTheme.textMuted),
                  SizedBox(width: 4),
                  Text('LOCKED', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.bgInput),
          ),
          child: Column(
            children: _dailySession!.blocks.asMap().entries.map((entry) {
              final index = entry.key;
              final block = entry.value;
              final isPast = index < _currentBlockIndex;
              final isCurrent = index == _currentBlockIndex;

              IconData icon;
              Color color;
              if (block.isStudy) {
                icon = Icons.menu_book_rounded;
                color = isPast ? AppTheme.textMuted : (isCurrent ? AppTheme.accentViolet : AppTheme.textSecondary);
              } else if (block.isBreak) {
                icon = Icons.coffee_rounded;
                color = isPast ? AppTheme.textMuted : (isCurrent ? AppTheme.accentEmerald : AppTheme.textSecondary);
              } else {
                icon = Icons.nights_stay;
                color = isPast ? AppTheme.textMuted : (isCurrent ? AppTheme.accentCyan : AppTheme.textSecondary);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPast ? Colors.transparent : color.withValues(alpha: 0.15),
                        border: Border.all(color: color.withValues(alpha: isPast ? 0 : 0.4)),
                      ),
                      child: Icon(
                        isPast ? Icons.check_rounded : icon,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: (block.isStudy && !isPast) ? () => _editTask(index, block) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              block.task != null && block.task!.isNotEmpty 
                                  ? block.task! 
                                  : (block.isStudy ? 'Study ${block.displaySubject}' : block.displaySubject),
                              style: TextStyle(
                                color: isPast ? AppTheme.textMuted : AppTheme.textPrimary,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                decoration: isPast ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (block.isStudy)
                              Text(
                                block.displaySubject,
                                style: TextStyle(
                                  color: isPast ? AppTheme.textMuted.withValues(alpha: 0.5) : AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (block.isStudy && !isPast)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: AppTheme.textMuted),
                        onPressed: () => _editTask(index, block),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '${block.durationMin}m',
                      style: TextStyle(
                        color: isPast ? AppTheme.textMuted : AppTheme.textSecondary,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
