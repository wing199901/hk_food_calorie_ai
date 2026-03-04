import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  final StorageService storage;

  const SettingsPage({super.key, required this.storage});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserProfile profile = UserProfile();
  int dailyTarget = 2000;
  bool showCalcInfo = false;
  bool showBMIInfo = false;
  bool showWHtRInfo = false;
  Map<String, String> errors = {};
  String _appVersion = '';

  static const _defaultProfile = {
    'age': 25,
    'weight': 70.0,
    'height': 175.0,
    'waistline': 80.0,
    'gender': 'male',
    'activityLevel': 'moderate',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.storage.addListener(_loadData);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(
        () => _appVersion = 'Version ${info.version}+${info.buildNumber}',
      );
    }
  }

  @override
  void dispose() {
    widget.storage.removeListener(_loadData);
    super.dispose();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      profile = widget.storage.getUserProfile();
      dailyTarget = widget.storage.getDailyTarget();
    });
  }

  double _calculateBMI() {
    final weight = profile.weight ?? _defaultProfile['weight'] as double;
    final height = profile.height ?? _defaultProfile['height'] as double;
    return double.parse(
      (weight / ((height / 100) * (height / 100))).toStringAsFixed(1),
    );
  }

  double _calculateWHtR() {
    final waist = profile.waistline ?? _defaultProfile['waistline'] as double;
    final height = profile.height ?? _defaultProfile['height'] as double;
    return double.parse((waist / height).toStringAsFixed(2));
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String _getWHtRCategory(double ratio) {
    if (ratio < 0.4) return 'Extremely Slim';
    if (ratio < 0.5) return 'Healthy';
    if (ratio < 0.6) return 'Overweight';
    return 'Obese';
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return AppTheme.chartWeight;
    if (bmi < 25) return AppTheme.primary;
    if (bmi < 30) return AppTheme.warning;
    return AppTheme.destructive;
  }

  Color _getWHtRColor(double ratio) {
    if (ratio < 0.4) return AppTheme.chartWeight;
    if (ratio < 0.5) return AppTheme.primary;
    if (ratio < 0.6) return AppTheme.warning;
    return AppTheme.destructive;
  }

  void _handleProfileChange(String field, dynamic value) {
    UserProfile newProfile;
    switch (field) {
      case 'age':
        newProfile = profile.copyWith(age: value as int);
        break;
      case 'weight':
        newProfile = profile.copyWith(weight: (value as num).toDouble());
        break;
      case 'height':
        newProfile = profile.copyWith(height: (value as num).toDouble());
        break;
      case 'waistline':
        newProfile = profile.copyWith(waistline: (value as num).toDouble());
        break;
      case 'gender':
        newProfile = profile.copyWith(gender: value as String);
        break;
      case 'activityLevel':
        newProfile = profile.copyWith(activityLevel: value as String);
        break;
      default:
        return;
    }
    setState(() => profile = newProfile);
    widget.storage.setUserProfile(newProfile);
  }

  void _handleClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text(
          'Are you sure you want to clear all meal data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.storage.clearDemoData();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppTheme.destructive),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBMI = _calculateBMI();
    final currentWHtR = _calculateWHtR();

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
                  // Personal Information
                  _buildSection(
                    icon: Icons.person,
                    iconColor: AppTheme.primary,
                    title: 'Personal Information',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(
                                'Age',
                                profile.age?.toString() ?? '',
                                '25',
                                (v) => _handleProfileChange(
                                  'age',
                                  int.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dropdownField(
                                'Gender',
                                profile.gender ?? 'male',
                                {
                                  'male': 'Male',
                                  'female': 'Female',
                                  'other': 'Other',
                                },
                                (v) => _handleProfileChange('gender', v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(
                                'Weight (kg)',
                                profile.weight?.toString() ?? '',
                                '70',
                                (v) => _handleProfileChange(
                                  'weight',
                                  double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _numberField(
                                'Height (cm)',
                                profile.height?.toString() ?? '',
                                '175',
                                (v) => _handleProfileChange(
                                  'height',
                                  double.tryParse(v) ?? 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _numberField(
                          'Waistline (cm)',
                          profile.waistline?.toString() ?? '',
                          '80',
                          (v) => _handleProfileChange(
                            'waistline',
                            double.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _dropdownField(
                          'Activity Level',
                          profile.activityLevel ?? 'moderate',
                          {
                            'sedentary': 'Sedentary (little/no exercise)',
                            'light': 'Light (1-3 days/week)',
                            'moderate': 'Moderate (3-5 days/week)',
                            'active': 'Active (6-7 days/week)',
                            'very-active': 'Very Active (2x per day)',
                          },
                          (v) => _handleProfileChange('activityLevel', v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // TEE
                  _buildSection(
                    icon: Icons.gps_fixed,
                    iconColor: AppTheme.accent,
                    title: 'Total Energy Expenditure',
                    trailing: GestureDetector(
                      onTap: () => setState(() => showCalcInfo = !showCalcInfo),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily Target',
                                style: TextStyle(
                                  color: AppTheme.mutedForeground,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$dailyTarget',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'kcal/day',
                                    style: TextStyle(
                                      color: AppTheme.mutedForeground,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (showCalcInfo) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Text(
                              'What is TEE?\n\nTotal Energy Expenditure (TEE) represents the total amount of calories your body burns in a single day.\n\nIt is calculated by multiplying your Basal Metabolic Rate (BMR) — the energy your body needs at rest — by your Physical Activity Level (PAL).\n\nThis helps determine exactly how much you should eat to maintain your current weight based on the scientific FAO/WHO/UNU (2001) standards.',
                              style: TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // BMI
                  _buildSection(
                    icon: Icons.calculate,
                    iconColor: AppTheme.primary,
                    title: 'Body Mass Index (BMI)',
                    trailing: GestureDetector(
                      onTap: () => setState(() => showBMIInfo = !showBMIInfo),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your BMI',
                                style: TextStyle(
                                  color: AppTheme.mutedForeground,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$currentBMI',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _getBMIColor(currentBMI),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getBMICategory(currentBMI),
                                    style: const TextStyle(
                                      color: AppTheme.mutedForeground,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (showBMIInfo) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Text(
                              'What is BMI?\n\nBody Mass Index (BMI) is a simple index of weight-for-height that is commonly used to classify underweight, overweight and obesity in adults.\n\n• Underweight: < 18.5\n• Normal weight: 18.5 – 24.9\n• Overweight: 25 – 29.9\n• Obesity: ≥ 30',
                              style: TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // WHtR
                  _buildSection(
                    icon: Icons.straighten,
                    iconColor: AppTheme.primary,
                    title: 'Waist-to-Height Ratio',
                    trailing: GestureDetector(
                      onTap: () => setState(() => showWHtRInfo = !showWHtRInfo),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Ratio',
                                style: TextStyle(
                                  color: AppTheme.mutedForeground,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$currentWHtR',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _getWHtRColor(currentWHtR),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getWHtRCategory(currentWHtR),
                                    style: const TextStyle(
                                      color: AppTheme.mutedForeground,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (showWHtRInfo) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Text(
                              'Waist-to-Height Ratio (WHtR)\n\nWHtR is a better predictor of health risks than BMI because it accounts for abdominal fat distribution.\n\n• Healthy: 0.4 - 0.49\n• Overweight: 0.5 - 0.59\n• Obese: ≥ 0.6',
                              style: TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Data Management
                  _buildSection(
                    icon: Icons.delete,
                    iconColor: AppTheme.destructive,
                    title: 'Data Management',
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _handleClearData,
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Clear All Meal Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.destructive.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: AppTheme.destructive,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This will permanently delete all your meal history. This action cannot be undone.',
                          style: TextStyle(
                            color: AppTheme.mutedForeground,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // About
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.1),
                          AppTheme.accent.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About FitCalorie',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Track your meals, analyze your nutrition, and reach your fitness goals with AI-powered food recognition.',
                          style: TextStyle(
                            color: AppTheme.mutedForeground,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _appVersion.isEmpty ? 'Version —' : _appVersion,
                          style: const TextStyle(
                            color: AppTheme.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sign Out
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _handleSignOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.destructive,
                        side: BorderSide(
                          color: AppTheme.destructive.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // The StreamBuilder in AppLoader listens to authStateChanges and will
      // automatically redirect to AuthPage once signOut completes.
      await SupabaseService().signOut();
    }
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing, // ignore: use_null_aware_elements
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _numberField(
    String label,
    String value,
    String hint,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.mutedForeground),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dropdownField(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.containsKey(value) ? value : options.keys.first,
              isExpanded: true,
              items: options.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
