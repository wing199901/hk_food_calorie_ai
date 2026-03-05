import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user_profile.dart';
import '../../core/theme/app_theme.dart';

/// Two-step onboarding page shown after first sign-up.
class CompleteProfilePage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const CompleteProfilePage({super.key, required this.onComplete});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  int _step = 0; // 0 = step 1 (required), 1 = step 2 (optional)

  // Step 1: Required
  DateTime? _birthdate;
  String _gender = 'male';
  final _heightCtrl = TextEditingController();

  // Step 2: Optional
  final _weightCtrl = TextEditingController();
  final _waistlineCtrl = TextEditingController();
  String _activityLevel = 'moderate';

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _waistlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _birthdate = picked);
    }
  }

  void _goToStep2() {
    // Validate step 1
    if (_birthdate == null) {
      _showError('Please select your birthdate.');
      return;
    }
    final height = double.tryParse(_heightCtrl.text);
    if (height == null || height <= 0) {
      _showError('Please enter a valid height.');
      return;
    }
    setState(() => _step = 1);
  }

  void _handleSave() {
    final storage = ref.read(storageProvider);
    final height = double.tryParse(_heightCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    final waistline = double.tryParse(_waistlineCtrl.text);

    final profile = UserProfile(
      birthdate: _birthdate != null
          ? DateFormat('yyyy-MM-dd').format(_birthdate!)
          : null,
      gender: _gender,
      height: height,
      weight: weight,
      waistline: waistline,
      activityLevel: _activityLevel,
    );
    storage.setUserProfile(profile);
    widget.onComplete();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress indicator
                  _buildProgressDots(),
                  const SizedBox(height: 48),
                  // Title
                  Text(
                    _step == 0
                        ? 'Complete Your Profile'
                        : 'Almost There!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == 0
                        ? 'We need a few details to calculate your daily targets.'
                        : 'Optional — helps us fine-tune your calorie goal.',
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Form
                  if (_step == 0) _buildStep1() else _buildStep2(),
                  const SizedBox(height: 48),
                  // Action buttons
                  if (_step == 0) _buildStep1Buttons() else _buildStep2Buttons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Progress Dots ───────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(isActive: true),
        const SizedBox(width: 8),
        _dot(isActive: _step == 1),
      ],
    );
  }

  Widget _dot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary : AppTheme.muted,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ─── Step 1: Required Fields ─────────────────────────────────

  Widget _buildStep1() {
    return Column(
      children: [
        // Birthdate
        _buildFieldLabel('Birthdate', isRequired: true),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthdate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthdate != null
                        ? DateFormat('yyyy-MM-dd').format(_birthdate!)
                        : 'Select your birthdate',
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthdate != null
                          ? AppTheme.foreground
                          : AppTheme.mutedForeground,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Gender
        _buildFieldLabel('Gender', isRequired: true),
        const SizedBox(height: 8),
        _buildGenderSelector(),
        const SizedBox(height: 24),
        // Height
        _buildFieldLabel('Height (cm)', isRequired: true),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _heightCtrl,
          hint: '175',
          icon: Icons.height,
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    const options = [
      ('male', 'Male', Icons.male),
      ('female', 'Female', Icons.female),
      ('other', 'Other', Icons.transgender),
    ];
    return Row(
      children: options.map((opt) {
        final isSelected = _gender == opt.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: opt.$1 != 'other' ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _gender = opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      opt.$3,
                      size: 24,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.mutedForeground,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Step 2: Optional Fields ─────────────────────────────────

  Widget _buildStep2() {
    return Column(
      children: [
        _buildFieldLabel('Weight (kg)'),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _weightCtrl,
          hint: '70',
          icon: Icons.monitor_weight_outlined,
        ),
        const SizedBox(height: 24),
        _buildFieldLabel('Waistline (cm)'),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _waistlineCtrl,
          hint: '80',
          icon: Icons.straighten,
        ),
        const SizedBox(height: 24),
        _buildFieldLabel('Activity Level'),
        const SizedBox(height: 8),
        _buildActivitySelector(),
      ],
    );
  }

  Widget _buildActivitySelector() {
    const levels = [
      ('sedentary', 'Sedentary', 'Little/no exercise'),
      ('light', 'Light', '1-3 days/week'),
      ('moderate', 'Moderate', '3-5 days/week'),
      ('active', 'Active', '6-7 days/week'),
      ('very-active', 'Very Active', '2x per day'),
    ];
    return Column(
      children: levels.map((level) {
        final isSelected = _activityLevel == level.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => _activityLevel = level.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.$2,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.foreground,
                          ),
                        ),
                        Text(
                          level.$3,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      size: 24,
                      color: AppTheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Action Buttons ──────────────────────────────────────────

  Widget _buildStep1Buttons() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _goToStep2,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Buttons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Save & Start Tracking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8),
                Icon(Icons.check_circle_outline, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _handleSave,
          child: const Text(
            'Skip for now',
            style: TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared Helpers ──────────────────────────────────────────

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: AppTheme.destructive)),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.mutedForeground),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}
