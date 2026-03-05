import 'package:flutter/cupertino.dart';
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
  Map<String, String> errors = {};
  String _appVersion = '';

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
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear Data'),
        content: const Text(
          'Are you sure you want to clear all meal data? This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              widget.storage.clearDemoData();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
