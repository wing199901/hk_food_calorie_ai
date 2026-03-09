import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user_profile.dart';
import '../../core/theme/app_theme.dart';
import '../settings/widgets/settings_section.dart';
import '../settings/widgets/settings_read_only_row.dart';
import '../onboarding/widgets/profile_gender_selector.dart';
import '../onboarding/widgets/profile_field_label.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late UserProfile _profile;
  bool _isEditing = false;
  bool _isSaving = false;

  // Edit state
  DateTime? _editBirthdate;
  String? _editGender;

  // Computed age from the in-progress edit (real-time)
  int? get _displayAge {
    final dt = _isEditing ? _editBirthdate : (_profile.birthdate != null ? DateTime.tryParse(_profile.birthdate!) : null);
    if (dt == null) return null;
    final now = DateTime.now();
    int years = now.year - dt.year;
    if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) {
      years--;
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    _profile = ref.read(storageProvider).getUserProfile();
    _editBirthdate = _profile.birthdate != null ? DateTime.tryParse(_profile.birthdate!) : null;
    _editGender = _profile.gender;
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    DateTime temp = _editBirthdate ?? DateTime(now.year - 25);
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
                    setState(() => _editBirthdate = temp);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: temp,
                minimumDate: DateTime(1920),
                maximumDate: now,
                onDateTimeChanged: (dt) {
                  temp = dt;
                  // Real-time age update while scrolling
                  setState(() => _editBirthdate = dt);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final newProfile = _profile.copyWith(
        birthdate: _editBirthdate != null
            ? DateFormat('yyyy-MM-dd').format(_editBirthdate!)
            : _profile.birthdate,
        gender: _editGender ?? _profile.gender,
      );
      await ref.read(storageProvider).setUserProfile(newProfile);
      if (!mounted) return;
      setState(() {
        _profile = newProfile;
        _isEditing = false;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      _saveProfile();
    } else {
      setState(() {
        _editBirthdate = _profile.birthdate != null
            ? DateTime.tryParse(_profile.birthdate!)
            : null;
        _editGender = _profile.gender;
        _isEditing = true;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _editBirthdate = _profile.birthdate != null
          ? DateTime.tryParse(_profile.birthdate!)
          : null;
      _editGender = _profile.gender;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final birthdateDisplay = _isEditing
        ? (_editBirthdate != null
            ? DateFormat('yyyy-MM-dd').format(_editBirthdate!)
            : 'Tap to select')
        : (_profile.birthdate ?? '—');

    final genderDisplay = _isEditing
        ? (_editGender ?? 'male')
        : (_profile.gender ?? '—');

    final genderLabel = {
      'male': 'Male',
      'female': 'Female',
      'other': 'Other',
    };

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Green gradient header ──
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
                children: [
                  // Back row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Account Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage your personal information',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SettingsSection(
                icon: Icons.person,
                iconColor: AppTheme.primary,
                title: 'Profile Details',
                trailing: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEditing)
                            GestureDetector(
                              onTap: _cancelEdit,
                              child: const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: _toggleEdit,
                            child: Text(
                              _isEditing ? 'Save' : 'Edit',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                child: Column(
                  children: [
                    // Birthdate
                    SettingsReadOnlyRow(
                      label: 'Birthdate',
                      value: birthdateDisplay,
                      onTap: _isEditing ? _pickBirthdate : null,
                    ),
                    const SizedBox(height: 12),
                    // Age — updates in real-time when birthdate changes
                    SettingsReadOnlyRow(
                      label: 'Age',
                      value: _displayAge != null ? _displayAge.toString() : '—',
                    ),
                    const SizedBox(height: 12),
                    // Gender
                    if (_isEditing) ...[
                      ProfileFieldLabel('Gender'),
                      const SizedBox(height: 8),
                      ProfileGenderSelector(
                        value: _editGender ?? 'male',
                        onChanged: (v) => setState(() => _editGender = v),
                      ),
                    ] else
                      SettingsReadOnlyRow(
                        label: 'Gender',
                        value: genderLabel[genderDisplay] ?? genderDisplay,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
