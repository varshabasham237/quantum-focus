import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// 3-Step Onboarding Wizard — collects student details after sign-up.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Personal
  final _ageController = TextEditingController();
  String _category = 'ug';

  // Step 2: Academic
  final _numSubjectsController = TextEditingController();
  final _dailyStudyHoursController = TextEditingController();
  List<String> _subjects = [];
  final _subjectInputController = TextEditingController();

  // Step 3: Lifestyle
  List<String> _hobbies = [];
  final _hobbyInputController = TextEditingController();
  final _hobbyHoursController = TextEditingController();
  List<String> _distractions = [];
  final _distractionInputController = TextEditingController();
  List<String> _distractingApps = [];
  final _appInputController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _numSubjectsController.dispose();
    _dailyStudyHoursController.dispose();
    _subjectInputController.dispose();
    _hobbyInputController.dispose();
    _hobbyHoursController.dispose();
    _distractionInputController.dispose();
    _appInputController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  void _addToList(List<String> list, TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isNotEmpty && !list.contains(value)) {
      setState(() {
        list.add(value);
        controller.clear();
      });
    }
  }

  void _removeFromList(List<String> list, int index) {
    setState(() => list.removeAt(index));
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final result = await auth.api.post('/profile/complete', {
      'personal': {
        'age': int.tryParse(_ageController.text) ?? 18,
        'category': _category,
      },
      'academic': {
        'num_subjects': int.tryParse(_numSubjectsController.text) ?? _subjects.length,
        'subjects': _subjects,
        'subject_ranking': _subjects,
        'daily_study_hours': double.tryParse(_dailyStudyHoursController.text) ?? 4.0,
      },
      'lifestyle': {
        'hobbies': _hobbies,
        'hobby_hours': double.tryParse(_hobbyHoursController.text) ?? 0.0,
        'daily_distractions': _distractions,
        'distracting_apps': _distractingApps,
      },
    });

    setState(() => _isLoading = false);

    if (mounted) {
      if (result != null && result['error'] == null) {
        auth.markProfileComplete();
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'Failed to save profile'),
            backgroundColor: AppTheme.accentRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          onPressed: _prevStep,
                          icon: const Icon(Icons.arrow_back_ios, size: 20),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          _stepTitles[_currentStep],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProgressBar(),
                  const SizedBox(height: 8),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPersonalStep(),
                  _buildAcademicStep(),
                  _buildLifestyleStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _stepTitles = ['Personal Details', 'Academic Details', 'Lifestyle & Distractions'];

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: isActive ? AppTheme.gradientPrimary : null,
              color: isActive ? null : AppTheme.bgCard,
            ),
          ),
        );
      }),
    );
  }

  // ==================== STEP 1: PERSONAL ====================
  Widget _buildPersonalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIcon(Icons.person_outline, 'Tell us about yourself'),
          const SizedBox(height: 28),
          const Text('Age', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Enter your age', prefixIcon: Icon(Icons.cake_outlined)),
          ),
          const SizedBox(height: 24),
          const Text('Category', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildCategorySelector(),
          const SizedBox(height: 40),
          _buildNextButton('Continue to Academic Details'),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'value': 'school', 'label': 'School', 'icon': Icons.school_outlined},
      {'value': 'ug', 'label': 'Undergraduate', 'icon': Icons.menu_book_outlined},
      {'value': 'pg', 'label': 'Postgraduate', 'icon': Icons.auto_stories_outlined},
    ];
    return Column(
      children: categories.map((cat) {
        final isSelected = _category == cat['value'];
        return GestureDetector(
          onTap: () => setState(() => _category = cat['value'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentViolet.withValues(alpha: 0.15) : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? AppTheme.accentViolet : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(cat['icon'] as IconData, color: isSelected ? AppTheme.accentViolet : AppTheme.textMuted, size: 22),
                const SizedBox(width: 12),
                Text(cat['label'] as String, style: TextStyle(
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, fontSize: 15,
                )),
                const Spacer(),
                if (isSelected) const Icon(Icons.check_circle, color: AppTheme.accentViolet, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== STEP 2: ACADEMIC ====================
  Widget _buildAcademicStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIcon(Icons.menu_book_outlined, 'Your study profile'),
          const SizedBox(height: 28),
          const Text('Number of Subjects', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _numSubjectsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'How many subjects?', prefixIcon: Icon(Icons.format_list_numbered)),
          ),
          const SizedBox(height: 24),
          _buildChipInput('Subjects (Strong → Weak)', 'Add a subject', _subjectInputController, _subjects, Icons.subject),
          const SizedBox(height: 24),
          const Text('Daily Study Hours', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _dailyStudyHoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Hours per day', prefixIcon: Icon(Icons.schedule)),
          ),
          const SizedBox(height: 40),
          _buildNextButton('Continue to Lifestyle'),
        ],
      ),
    );
  }

  // ==================== STEP 3: LIFESTYLE ====================
  Widget _buildLifestyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIcon(Icons.self_improvement, 'Your lifestyle'),
          const SizedBox(height: 28),
          _buildChipInput('Hobbies', 'Add a hobby', _hobbyInputController, _hobbies, Icons.sports_esports_outlined),
          const SizedBox(height: 20),
          const Text('Time for Hobbies (hours/day)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _hobbyHoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Hours per day', prefixIcon: Icon(Icons.timer_outlined)),
          ),
          const SizedBox(height: 24),
          _buildChipInput('Daily Distractions', 'Add a distraction', _distractionInputController, _distractions, Icons.notifications_active_outlined),
          const SizedBox(height: 24),
          _buildChipInput('Distracting Apps', 'Add an app name', _appInputController, _distractingApps, Icons.phone_android),
          const SizedBox(height: 40),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppTheme.accentViolet.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitProfile,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch, color: Colors.white),
                label: Text(_isLoading ? 'Saving...' : 'Complete Setup',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _buildSectionIcon(IconData icon, String subtitle) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle, gradient: AppTheme.gradientPrimary,
            boxShadow: [BoxShadow(color: AppTheme.accentViolet.withValues(alpha: 0.3), blurRadius: 20)],
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      ],
    );
  }

  Widget _buildNextButton(String label) {
    return SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentViolet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChipInput(String label, String hint, TextEditingController controller, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                onFieldSubmitted: (_) => _addToList(items, controller),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: AppTheme.accentViolet, borderRadius: BorderRadius.circular(12)),
              child: IconButton(onPressed: () => _addToList(items, controller), icon: const Icon(Icons.add, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(items.length, (index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentViolet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentViolet.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(items[index], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeFromList(items, index),
                    child: Icon(Icons.close, size: 16, color: AppTheme.accentRose.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
