import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/body_metric.dart';
import '../../shared/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/unit_converter.dart';
import '../onboarding/complete_profile_page.dart';
import '../profile/profile_page.dart';
import 'widgets/body_metrics_section.dart';
import 'widgets/about_section.dart';
import 'widgets/sign_out_button.dart';
import 'widgets/weight_goal_section.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  UserProfile _profile = UserProfile();
  String _appVersion = '';

  // Body Metrics controllers
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _waistlineCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVersion();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _waistlineCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(
        () => _appVersion = 'Version ${info.version}+${info.buildNumber}',
      );
    }
  }

  void _loadData() {
    if (!mounted) return;
    final storage = ref.read(storageProvider);
    final profile = storage.getUserProfile();
    final isMetric = (profile.unitSystem ?? 'metric') == 'metric';
    setState(() {
      _profile = profile;
      _weightCtrl.text = UnitConverter.weightToDisplay(
        profile.weight,
        isMetric: isMetric,
      );
      _heightCtrl.text = UnitConverter.heightToDisplay(
        profile.height,
        isMetric: isMetric,
      );
      _waistlineCtrl.text = UnitConverter.lengthToDisplay(
        profile.waistline,
        isMetric: isMetric,
      );
      _targetWeightCtrl.text = UnitConverter.weightToDisplay(
        profile.targetWeight,
        isMetric: isMetric,
      );
    });
  }

  // ─── Account Profile ─────────────────────────────────────────

  void _openProfilePage() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfilePage()))
        .then((_) => _loadData()); // refresh on return
  }

  // ─── Profile Nav Row ─────────────────────────────────────────

  Widget _buildProfileNavRow() {
    return GestureDetector(
      onTap: _openProfilePage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person,
                size: 20,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Body Metrics ────────────────────────────────────────────

  void _handleUpdateToday() {
    final storage = ref.read(storageProvider);
    final isMetric = (_profile.unitSystem ?? 'metric') == 'metric';
    final newWeight = UnitConverter.parseWeight(
      _weightCtrl.text,
      isMetric: isMetric,
    );
    final newHeight = UnitConverter.parseHeight(
      _heightCtrl.text,
      isMetric: isMetric,
    );
    final newWaistline = UnitConverter.parseLength(
      _waistlineCtrl.text,
      isMetric: isMetric,
    );
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Keep advanced goals unchanged and only quick-edit essential metrics.
    final newProfile = _profile.copyWith(
      weight: newWeight ?? _profile.weight,
      height: newHeight ?? _profile.height,
      waistline: newWaistline ?? _profile.waistline,
    );
    storage.setUserProfile(newProfile);

    // Save today's weight snapshot for trend continuity.
    storage.addBodyMetric(
      BodyMetric(date: todayStr, weight: newWeight, waistline: newWaistline),
    );

    setState(() => _profile = newProfile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Body metrics updated'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _refreshWeightGoalPreview(_) {
    if (!mounted) return;
    setState(() {});
  }

  String _buildHealthyWeightCaption() {
    final isMetric = (_profile.unitSystem ?? 'metric') == 'metric';
    final unit = isMetric ? 'kg' : 'lbs';

    final heightCm =
        UnitConverter.parseHeight(_heightCtrl.text, isMetric: isMetric) ??
        _profile.height;
    final guide = StorageService.calculateHealthyWeightGuide(
      heightCm: heightCm,
      gender: _profile.gender,
    );

    if (guide == null) {
      return 'Enter height to preview healthy weight range.';
    }

    final minDisplay = isMetric ? guide.minKg : UnitConverter.kgToLbs(guide.minKg);
    final maxDisplay = isMetric ? guide.maxKg : UnitConverter.kgToLbs(guide.maxKg);

    return 'Healthy range: ${minDisplay.toStringAsFixed(1)} ~ '
        '${maxDisplay.toStringAsFixed(1)} $unit (BMI 18.5 to Devine IBW)';
  }

  ({String value, Color valueColor}) _buildGoalSummary() {
    final isMetric = (_profile.unitSystem ?? 'metric') == 'metric';
    final unit = isMetric ? 'kg' : 'lbs';

    final currentWeightKg =
        UnitConverter.parseWeight(_weightCtrl.text, isMetric: isMetric) ??
        _profile.weight;
    final targetWeightKg = UnitConverter.parseWeight(
      _targetWeightCtrl.text,
      isMetric: isMetric,
    );

    if (currentWeightKg == null ||
        currentWeightKg <= 0 ||
        targetWeightKg == null ||
        targetWeightKg <= 0) {
      return (
        value: 'Enter weight and target weight to calculate goal.',
        valueColor: AppTheme.mutedForeground,
      );
    }

    final direction = StorageService.inferGoalDirection(
      currentWeight: currentWeightKg,
      targetWeight: targetWeightKg,
    );

    final deltaKg = targetWeightKg - currentWeightKg;
    final deltaDisplay = isMetric ? deltaKg : UnitConverter.kgToLbs(deltaKg);
    final heightCm =
        UnitConverter.parseHeight(_heightCtrl.text, isMetric: isMetric) ??
        _profile.height;

    String withGoalBmi(String deltaLabel) {
      if (heightCm == null || heightCm <= 0) return deltaLabel;
      final heightM = heightCm / 100;
      final targetBmi = targetWeightKg / (heightM * heightM);
      return '$deltaLabel, ${targetBmi.toStringAsFixed(1)} BMI';
    }

    if (direction == 'maintain') {
      return (
        value: withGoalBmi('0.0 $unit'),
        valueColor: AppTheme.mutedForeground,
      );
    }

    if (direction == 'gain') {
      return (
        value: withGoalBmi('+${deltaDisplay.abs().toStringAsFixed(1)} $unit'),
        valueColor: AppTheme.primary,
      );
    }

    return (
      value: withGoalBmi('-${deltaDisplay.abs().toStringAsFixed(1)} $unit'),
      valueColor: AppTheme.accent,
    );
  }

  void _handleSaveWeightGoal() {
    final storage = ref.read(storageProvider);
    final isMetric = (_profile.unitSystem ?? 'metric') == 'metric';
    final inputWeight = UnitConverter.parseWeight(
      _weightCtrl.text,
      isMetric: isMetric,
    );
    final targetWeight = UnitConverter.parseWeight(
      _targetWeightCtrl.text,
      isMetric: isMetric,
    );
    final hasTargetInput = _targetWeightCtrl.text.trim().isNotEmpty;

    if (hasTargetInput && (targetWeight == null || targetWeight <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid target weight.'),
          backgroundColor: AppTheme.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newProfile = _profile.copyWith(
      weight: inputWeight ?? _profile.weight,
      targetWeight: targetWeight,
      clearTargetWeight: !hasTargetInput,
    );

    storage.setUserProfile(newProfile);

    setState(() => _profile = newProfile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Weight goal updated'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _runSetupAgain() async {
    final didComplete = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteProfilePage(
          initialProfile: _profile,
          onComplete: () => Navigator.of(context).pop(true),
        ),
      ),
    );

    if (didComplete == true && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup completed'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildRunSetupAgainButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _runSetupAgain,
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Run Setup Again'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildRunSetupAgainHint() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Use this to review your target-weight setup in guided steps.',
        style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
      ),
    );
  }

  // ─── Sign Out ────────────────────────────────────────────────

  Future<void> _handleSignOut() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(supabaseProvider).signOut();
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(storageProvider);
    final isMetric = (_profile.unitSystem ?? 'metric') == 'metric';
    final goalSummary = _buildGoalSummary();

    return Column(
      children: [
        // Sticky Header
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Personalize your experience',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Account Profile — navigate to dedicated page
                  _buildProfileNavRow(),
                  const SizedBox(height: 24),
                  BodyMetricsSection(
                    weightCtrl: _weightCtrl,
                    heightCtrl: _heightCtrl,
                    waistlineCtrl: _waistlineCtrl,
                    onUpdateToday: _handleUpdateToday,
                    isMetric: isMetric,
                    onWeightChanged: _refreshWeightGoalPreview,
                  ),
                  const SizedBox(height: 24),
                  WeightGoalSection(
                    targetWeightCtrl: _targetWeightCtrl,
                    healthyRangeCaption: _buildHealthyWeightCaption(),
                    goalSummaryValue: goalSummary.value,
                    goalSummaryValueColor: goalSummary.valueColor,
                    onTargetWeightChanged: _refreshWeightGoalPreview,
                    onSave: _handleSaveWeightGoal,
                    isMetric: isMetric,
                  ),
                  const SizedBox(height: 24),

                  AboutSection(appVersion: _appVersion),
                  const SizedBox(height: 24),
                  _buildRunSetupAgainButton(),
                  const SizedBox(height: 8),
                  _buildRunSetupAgainHint(),
                  const SizedBox(height: 24),
                  SignOutButton(onSignOut: _handleSignOut),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
