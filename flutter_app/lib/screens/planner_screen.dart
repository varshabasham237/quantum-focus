import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/planner_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Study Planner Screen — shows Heavy / Medium / Light focus plans
/// generated from the student's profile. Study blocks are editable;
/// break and free-time blocks are locked.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StudyPlan? _plan;
  bool _loading = true;
  String? _error;

  // Track unsaved changes per mode
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final result = await auth.api.get('/planner/generate');
    if (!mounted) return;
    if (result == null || result.containsKey('error')) {
      setState(() {
        _error = result?['error'] ?? 'Failed to generate plan';
        _loading = false;
      });
    } else {
      setState(() {
        _plan = StudyPlan.fromJson(result);
        _loading = false;
      });
    }
  }

  Future<void> _saveChanges(PlanMode mode) async {
    if (_plan == null) return;
    setState(() => _saving = true);

    final dayPlan = _plan!.byMode(mode);
    final updates = <Map<String, dynamic>>[];

    for (int i = 0; i < dayPlan.blocks.length; i++) {
      final block = dayPlan.blocks[i];
      if (block.editable &&
          (block.editedSubject != null || block.editedDuration != null)) {
        updates.add({
          'block_index': i,
          if (block.editedSubject != null) 'subject': block.editedSubject,
          if (block.editedDuration != null)
            'duration_min': block.editedDuration,
        });
      }
    }

    final auth = context.read<AuthService>();
    final result = await auth.api.patch('/planner/update', {
      'mode': mode.apiKey,
      'updates': updates,
    });

    setState(() {
      _saving = false;
      _hasChanges = false;
    });

    if (!mounted) return;
    if (result == null || result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: ${result?['error'] ?? 'Unknown error'}'),
        backgroundColor: AppTheme.accentRose,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Plan saved!'),
        backgroundColor: AppTheme.accentEmerald,
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('📘 Study Planner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
            onPressed: _loadPlan,
            tooltip: 'Regenerate',
          ),
        ],
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accentViolet,
                labelColor: AppTheme.accentViolet,
                unselectedLabelColor: AppTheme.textMuted,
                tabs: PlanMode.values.map((m) => Tab(text: m.label)).toList(),
              ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentViolet),
                  SizedBox(height: 16),
                  Text('Generating your plan...',
                      style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: PlanMode.values
                      .map((m) => _buildModeTab(m))
                      .toList(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPlan,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentViolet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(PlanMode mode) {
    final dayPlan = _plan!.byMode(mode);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildModeHeader(mode, dayPlan)),
        SliverToBoxAdapter(child: _buildStatsSummary(dayPlan)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildBlockCard(dayPlan.blocks[index], index, mode),
            childCount: dayPlan.blocks.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              children: [
                _buildSaveButton(mode),
                const SizedBox(height: 16),
                _buildOptimizeButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeHeader(PlanMode mode, DayPlan dayPlan) {
    final colors = {
      PlanMode.heavy: AppTheme.accentRose,
      PlanMode.medium: AppTheme.accentViolet,
      PlanMode.light: AppTheme.accentEmerald,
    };
    final color = colors[mode]!;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(mode.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mode.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(DayPlan dayPlan) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _buildStatChip('📚 Study', '${dayPlan.totalStudyMin}m', AppTheme.accentViolet),
          const SizedBox(width: 10),
          _buildStatChip('☕ Break', '${dayPlan.totalBreakMin}m', AppTheme.accentCyan),
          const SizedBox(width: 10),
          _buildStatChip('🌿 Free', '${dayPlan.totalFreeMin}m', AppTheme.accentEmerald),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(PlanBlock block, int index, PlanMode mode) {
    if (block.isStudy) return _buildStudyBlock(block, index, mode);
    if (block.isBreak) return _buildLockedBlock(block, '☕ Break', AppTheme.accentCyan);
    return _buildLockedBlock(block, '🌿 Free Time', AppTheme.accentEmerald);
  }

  Widget _buildStudyBlock(PlanBlock block, int index, PlanMode mode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentViolet.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentViolet.withValues(alpha: 0.15),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_rounded,
                  color: AppTheme.accentViolet, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.displaySubject,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${block.displayDuration} minutes',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                color: AppTheme.accentCyan, size: 20),
            onPressed: () => _showEditDialog(block, index, mode),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBlock(PlanBlock block, String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: color.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 12),
          Text(
            '$label — ${block.durationMin} min',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(PlanMode mode) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.gradientPrimary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentViolet.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _saving ? null : () => _saveChanges(mode),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, color: Colors.white),
          label: Text(
            _saving ? 'Saving...' : 'Save Changes',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizeButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _loadPlan,
        icon: const Icon(Icons.auto_awesome, color: AppTheme.accentViolet),
        label: const Text(
          'Re-Optimize AI Schedule',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accentViolet),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.accentViolet, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  void _showEditDialog(PlanBlock block, int index, PlanMode mode) {
    final subjectCtrl =
        TextEditingController(text: block.editedSubject ?? block.subject ?? '');
    final durationCtrl = TextEditingController(
        text: '${block.editedDuration ?? block.durationMin}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('✏️ Edit Study Block',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon:
                    Icon(Icons.menu_book_outlined, color: AppTheme.textMuted),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.bgInput)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accentViolet)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                labelStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.textMuted),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.bgInput)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accentViolet)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final newDuration = int.tryParse(durationCtrl.text.trim());
              setState(() {
                block.editedSubject = subjectCtrl.text.trim().isEmpty
                    ? null
                    : subjectCtrl.text.trim();
                block.editedDuration =
                    (newDuration != null && newDuration >= 5) ? newDuration : null;
                _hasChanges = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply',
                style: TextStyle(
                    color: AppTheme.accentViolet,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
