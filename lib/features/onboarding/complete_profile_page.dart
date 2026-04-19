import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/body_metric.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/profile_progress_dots.dart';
import 'widgets/profile_field_label.dart';
import 'widgets/profile_input_field.dart';
import '../../shared/widgets/gender_selector.dart';
import '../../shared/widgets/unit_system_selector.dart';
import '../../shared/widgets/weight_goal_selector.dart';
import '../../core/utils/unit_converter.dart';
import 'widgets/profile_activity_selector.dart';

/// Two-step onboarding page shown after first sign-up or when profile is incomplete.
class CompleteProfilePage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final UserProfile? initialProfile;

  const CompleteProfilePage({
    super.key,
    required this.onComplete,
    this.initialProfile,
  });

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  int _step =
      0; // 0 = step 1 (required), 1 = step 2 (optional), 2 = step 3 (optional)

  // Step 1: Required
  DateTime? _birthdate;
  String _gender = 'male';
  String _unitSystem = 'metric';
  final _heightCtrl = TextEditingController();
  bool _isSaving = false;

  // Step 2: Optional
  final _weightCtrl = TextEditingController();
  final _goalWeightDeltaCtrl = TextEditingController();
  final _waistlineCtrl = TextEditingController();
  String _weightGoal = 'maintain';
  String _activityLevel = 'moderate';

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    if (p == null) return;
    if (p.birthdate != null) {
      _birthdate = DateTime.tryParse(p.birthdate!);
    }
    if (p.gender != null) _gender = p.gender!;
    if (p.unitSystem != null) _unitSystem = p.unitSystem!;
    final isMetric = _unitSystem == 'metric';
    if (p.height != null) {
      _heightCtrl.text = UnitConverter.heightToDisplay(
        p.height,
        isMetric: isMetric,
      );
    }
    if (p.weight != null) {
      _weightCtrl.text = UnitConverter.weightToDisplay(
        p.weight,
        isMetric: isMetric,
      );
    }
    if (p.goalWeightDelta != null) {
      _goalWeightDeltaCtrl.text = UnitConverter.weightToDisplay(
        p.goalWeightDelta,
        isMetric: isMetric,
      );
    }
    if (p.waistline != null) {
      _waistlineCtrl.text = UnitConverter.lengthToDisplay(
        p.waistline,
        isMetric: isMetric,
      );
    }
    if (p.weightGoal != null) _weightGoal = p.weightGoal!;
    if (p.activityLevel != null) _activityLevel = p.activityLevel!;
    if (_weightGoal == 'maintain') {
      _goalWeightDeltaCtrl.clear();
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _goalWeightDeltaCtrl.dispose();
    _waistlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final initialBirthDate =
        _birthdate ?? DateTime(now.year - 25, now.month, now.day);
    DateTime tempDate = initialBirthDate;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () {
                    setState(() => _birthdate = tempDate);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialBirthDate,
                maximumDate: DateTime.now(),
                minimumDate: DateTime(1920),
                onDateTimeChanged: (date) => tempDate = date,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToStep2() {
    if (_birthdate == null) {
      _showError('Please enter your birthdate.');
      return;
    }
    setState(() => _step = 1);
  }

  void _goToStep3() => setState(() => _step = 2);

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final isMetric = _unitSystem == 'metric';
      final height =
          UnitConverter.parseHeight(_heightCtrl.text, isMetric: isMetric) ??
          175.0;
      final weight = UnitConverter.parseWeight(
        _weightCtrl.text,
        isMetric: isMetric,
      );
      final goalWeightDelta = UnitConverter.parseWeight(
        _goalWeightDeltaCtrl.text,
        isMetric: isMetric,
      );
      final waistline = UnitConverter.parseLength(
        _waistlineCtrl.text,
        isMetric: isMetric,
      );

      final profile = UserProfile(
        birthdate: _birthdate != null
            ? DateFormat('yyyy-MM-dd').format(_birthdate!)
            : null,
        gender: _gender,
        height: height,
        weight: weight,
        weightGoal: _weightGoal,
        goalWeightDelta: _weightGoal == 'maintain' ? null : goalWeightDelta,
        waistline: waistline,
        activityLevel: _activityLevel,
        unitSystem: _unitSystem,
      );
      await ref.read(storageProvider).setUserProfile(profile);

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final storage = ref.read(storageProvider);
      storage.addBodyMetric(
        BodyMetric(date: todayStr, weight: weight, waistline: waistline),
      );
      storage.setLastCheckInDate(todayStr);

      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        debugPrint(error.toString());
        _showError(error.toString());
      }
    }
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

  String _buildStep2TargetWeightPreview() {
    final isMetric = _unitSystem == 'metric';
    final unit = isMetric ? 'kg' : 'lbs';

    final currentWeightKg = UnitConverter.parseWeight(
      _weightCtrl.text,
      isMetric: isMetric,
    );

    if (currentWeightKg == null || currentWeightKg <= 0) {
      return 'Enter weight to preview target weight.';
    }

    if (_weightGoal == 'maintain') {
      final displayWeight = isMetric
          ? currentWeightKg
          : UnitConverter.kgToLbs(currentWeightKg);
      return 'Target weight preview: ${displayWeight.toStringAsFixed(1)} $unit';
    }

    final goalDeltaKg = UnitConverter.parseWeight(
      _goalWeightDeltaCtrl.text,
      isMetric: isMetric,
    );

    if (goalDeltaKg == null || goalDeltaKg <= 0) {
      return 'Enter change amount to preview target weight.';
    }

    final targetWeightKg = _weightGoal == 'lose'
        ? currentWeightKg - goalDeltaKg
        : currentWeightKg + goalDeltaKg;

    if (targetWeightKg <= 0) {
      return 'Target weight must be above 0.';
    }

    final displayWeight = isMetric
        ? targetWeightKg
        : UnitConverter.kgToLbs(targetWeightKg);
    return 'Target weight preview: ${displayWeight.toStringAsFixed(1)} $unit';
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
                        : _step == 1
                        ? 'Almost There!'
                        : 'One Last Thing',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == 0
                        ? 'We need a few details to calculate your daily targets.'
                        : _step == 1
                        ? 'Set your weight goal direction and change amount.'
                        : 'How active are you on a typical day?',
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Form
                  if (_step == 0)
                    _buildStep1()
                  else if (_step == 1)
                    _buildStep2()
                  else
                    _buildStep3(),
                  const SizedBox(height: 48),
                  // Action buttons
                  if (_step == 0)
                    _buildStep1Buttons()
                  else if (_step == 1)
                    _buildStep2Buttons()
                  else
                    _buildStep3Buttons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Progress Dots ───────────────────────────────────────────

  Widget _buildProgressDots() => ProfileProgressDots(step: _step);

  // ─── Step 1: Required Fields ─────────────────────────────────

  Widget _buildStep1() {
    return Column(
      children: [
        // Unit System
        ProfileFieldLabel('Unit System', isRequired: false),
        const SizedBox(height: 8),
        UnitSystemSelector(
          value: _unitSystem,
          onChanged: (v) => setState(() => _unitSystem = v),
        ),
        const SizedBox(height: 24),
        // Birthdate
        ProfileFieldLabel('Birthdate', isRequired: true),
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
        ProfileFieldLabel('Gender', isRequired: true),
        const SizedBox(height: 8),
        GenderSelector(
          value: _gender,
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 24),
        // Height
        ProfileFieldLabel(
          'Height (${_unitSystem == 'metric' ? 'cm' : 'ft'})',
          isRequired: false,
        ),
        const SizedBox(height: 8),
        ProfileInputField(
          controller: _heightCtrl,
          hint: _unitSystem == 'metric' ? '175' : '5.7',
          icon: Icons.height,
        ),
      ],
    );
  }

  // ─── Step 2

  Widget _buildStep2() {
    final unit = _unitSystem == 'metric' ? 'kg' : 'lbs';
    final goalHint = _unitSystem == 'metric' ? '5' : '11';
    final goalHelper = switch (_weightGoal) {
      'lose' => 'Enter how much weight you want to lose.',
      'gain' => 'Enter how much weight you want to gain.',
      _ => 'Maintain keeps your current weight target.',
    };

    return Column(
      children: [
        ProfileFieldLabel('Weight (${_unitSystem == 'metric' ? 'kg' : 'lbs'})'),
        const SizedBox(height: 8),
        ProfileInputField(
          controller: _weightCtrl,
          hint: _unitSystem == 'metric' ? '70' : '154',
          icon: Icons.monitor_weight_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        ProfileFieldLabel('Goal Direction'),
        const SizedBox(height: 8),
        WeightGoalSelector(
          value: _weightGoal,
          onChanged: (value) {
            setState(() {
              _weightGoal = value;
              if (_weightGoal == 'maintain') {
                _goalWeightDeltaCtrl.clear();
              }
            });
          },
        ),
        const SizedBox(height: 24),
        ProfileFieldLabel('Change Amount ($unit)'),
        const SizedBox(height: 8),
        ProfileInputField(
          controller: _goalWeightDeltaCtrl,
          hint: goalHint,
          icon: Icons.flag_outlined,
          enabled: _weightGoal != 'maintain',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            goalHelper,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _buildStep2TargetWeightPreview(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ProfileFieldLabel(
          'Waistline (${_unitSystem == 'metric' ? 'cm' : 'in'})',
        ),
        const SizedBox(height: 8),
        ProfileInputField(
          controller: _waistlineCtrl,
          hint: _unitSystem == 'metric' ? '80' : '31',
          icon: Icons.straighten,
        ),
      ],
    );
  }

  // ─── Step 3: Activity Level ───────────────────────────────────

  Widget _buildStep3() {
    return Column(
      children: [
        ProfileFieldLabel('Activity Level'),
        const SizedBox(height: 8),
        ProfileActivitySelector(
          value: _activityLevel,
          onChanged: (v) => setState(() => _activityLevel = v),
        ),
      ],
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _goToStep3,
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

  Widget _buildStep3Buttons() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Save & Start Tracking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.check_circle_outline, size: 20),
                ],
              ),
      ),
    );
  }
}
