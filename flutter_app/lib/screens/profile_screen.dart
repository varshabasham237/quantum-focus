import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Read-only Profile Screen — displays all student details collected during onboarding.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthService>();
    final result = await auth.api.get('/profile/');
    if (mounted) {
      setState(() {
        _profile = result?['profile'] as Map<String, dynamic>?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.accentCyan),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentViolet))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // ── Avatar + Name Header ──
                  _buildHeader(auth),
                  const SizedBox(height: 24),

                  // ── Account Info ──
                  _buildSection(
                    icon: Icons.person_outline_rounded,
                    title: 'Account',
                    color: AppTheme.accentViolet,
                    children: [
                      _buildInfoRow('Username', auth.userName ?? '—'),
                      _buildInfoRow('Email', auth.userEmail ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Personal Details ──
                  _buildSection(
                    icon: Icons.badge_outlined,
                    title: 'Personal Details',
                    color: AppTheme.accentCyan,
                    children: _buildPersonalRows(),
                  ),
                  const SizedBox(height: 16),

                  // ── Academic Details ──
                  _buildSection(
                    icon: Icons.school_outlined,
                    title: 'Academic Details',
                    color: AppTheme.accentEmerald,
                    children: _buildAcademicRows(),
                  ),
                  const SizedBox(height: 16),

                  // ── Lifestyle & Hobbies ──
                  _buildSection(
                    icon: Icons.interests_outlined,
                    title: 'Lifestyle & Hobbies',
                    color: AppTheme.accentAmber,
                    children: _buildLifestyleRows(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final currentHours = _academic['daily_study_hours']?.toString() ?? '';
    final List<String> currentHobbiesList = List<String>.from(_lifestyle['hobbies'] ?? []);
    final currentHobbies = currentHobbiesList.join(', ');

    final hoursController = TextEditingController(text: currentHours);
    final hobbiesController = TextEditingController(text: currentHobbies);

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              title: const Text('Edit Profile', style: TextStyle(color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Update your daily study hours and hobbies (comma separated).',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: hoursController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Daily Study Hours',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.bgInput)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hobbiesController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Hobbies',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.bgInput)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                TextButton(
                  onPressed: isSaving ? null : () async {
                    setDialogState(() => isSaving = true);
                    double? parsedHours = double.tryParse(hoursController.text.trim());
                    List<String> parsedHobbies = hobbiesController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    final Map<String, dynamic> updateData = {};
                    if (parsedHours != null) updateData['daily_study_hours'] = parsedHours;
                    updateData['hobbies'] = parsedHobbies;

                    final response = await auth.api.patch('/profile/', updateData);
                    setDialogState(() => isSaving = false);

                    if (response != null && !response.containsKey('error') && mounted) {
                      Navigator.pop(context);
                      setState(() => _loading = true);
                      _loadProfile();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update: ${response?['error'] ?? 'Unknown error'}')),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan))
                      : const Text('Save', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Header with avatar circle ──
  Widget _buildHeader(AuthService auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentViolet.withValues(alpha: 0.15),
            AppTheme.accentCyan.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentViolet.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.gradientPrimary,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentViolet.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                (auth.userName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            auth.userName ?? 'Student',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            auth.userEmail ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Glassmorphism section card ──
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Single info row ──
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chip list row ──
  Widget _buildChipRow(String label, List<String> items, Color chipColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Ranked list (numbered) ──
  Widget _buildRankedRow(String label, List<String> items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final isStrong = rank <= 2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isStrong
                          ? AppTheme.accentEmerald.withValues(alpha: 0.2)
                          : AppTheme.accentRose.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isStrong ? AppTheme.accentEmerald : AppTheme.accentRose,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (rank == 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Strongest',
                        style: TextStyle(color: AppTheme.accentEmerald, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Data extraction helpers ──

  Map<String, dynamic> get _personal =>
      (_profile?['personal'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _academic =>
      (_profile?['academic'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _lifestyle =>
      (_profile?['lifestyle'] as Map<String, dynamic>?) ?? {};

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'school':
        return 'School Student';
      case 'ug':
        return 'Undergraduate (UG)';
      case 'pg':
        return 'Postgraduate (PG)';
      default:
        return '—';
    }
  }

  List<Widget> _buildPersonalRows() {
    if (_personal.isEmpty) {
      return [_buildInfoRow('Status', 'Not completed yet')];
    }
    return [
      _buildInfoRow('Age', '${_personal['age'] ?? '—'} years'),
      _buildInfoRow('Category', _categoryLabel(_personal['category'] as String?)),
    ];
  }

  List<Widget> _buildAcademicRows() {
    if (_academic.isEmpty) {
      return [_buildInfoRow('Status', 'Not completed yet')];
    }
    final subjects = List<String>.from(_academic['subjects'] ?? []);
    final ranking = List<String>.from(_academic['subject_ranking'] ?? []);
    return [
      _buildInfoRow('Subjects', '${_academic['num_subjects'] ?? subjects.length}'),
      _buildInfoRow('Daily Study', '${_academic['daily_study_hours'] ?? '—'} hours'),
      if (subjects.isNotEmpty)
        _buildChipRow('Subjects', subjects, AppTheme.accentEmerald),
      if (ranking.isNotEmpty)
        _buildRankedRow('Ranking (Strong → Weak)', ranking, AppTheme.accentCyan),
    ];
  }

  List<Widget> _buildLifestyleRows() {
    if (_lifestyle.isEmpty) {
      return [_buildInfoRow('Status', 'Not completed yet')];
    }
    final hobbies = List<String>.from(_lifestyle['hobbies'] ?? []);
    final distractions = List<String>.from(_lifestyle['daily_distractions'] ?? []);
    final distractingApps = List<String>.from(_lifestyle['distracting_apps'] ?? []);
    return [
      _buildInfoRow('Hobby Time', '${_lifestyle['hobby_hours'] ?? '—'} hrs / day'),
      if (hobbies.isNotEmpty)
        _buildChipRow('Hobbies', hobbies, AppTheme.accentAmber),
      if (distractions.isNotEmpty)
        _buildChipRow('Distractions', distractions, AppTheme.accentRose),
      if (distractingApps.isNotEmpty)
        _buildChipRow('Distracting Apps', distractingApps, AppTheme.accentRose),
    ];
  }
}
