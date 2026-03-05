import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import 'settings_section.dart';
import 'settings_read_only_row.dart';
import 'settings_dropdown_field.dart';

class AccountProfileSection extends StatelessWidget {
  const AccountProfileSection({
    super.key,
    required this.profile,
    required this.isEditing,
    required this.editBirthdate,
    required this.editGender,
    required this.onToggleEdit,
    required this.onPickBirthdate,
    required this.onGenderChanged,
  });

  final UserProfile profile;
  final bool isEditing;
  final DateTime? editBirthdate;
  final String? editGender;
  final VoidCallback onToggleEdit;
  final VoidCallback onPickBirthdate;
  final ValueChanged<String> onGenderChanged;

  static const _genderLabel = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final birthdateDisplay = isEditing
        ? (editBirthdate != null
            ? DateFormat('yyyy-MM-dd').format(editBirthdate!)
            : 'Tap to select')
        : (profile.birthdate ?? '—');

    final genderDisplay =
        isEditing ? (editGender ?? 'male') : (profile.gender ?? '—');

    return SettingsSection(
      icon: Icons.person,
      iconColor: AppTheme.primary,
      title: 'Account Profile',
      trailing: GestureDetector(
        onTap: onToggleEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isEditing
                ? AppTheme.primary.withValues(alpha: 0.1)
                : AppTheme.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEditing ? Icons.check : Icons.edit,
                size: 16,
                color:
                    isEditing ? AppTheme.primary : AppTheme.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(
                isEditing ? 'Save' : 'Edit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isEditing
                      ? AppTheme.primary
                      : AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        children: [
          SettingsReadOnlyRow(
            label: 'Birthdate',
            value: birthdateDisplay,
            onTap: isEditing ? onPickBirthdate : null,
          ),
          const SizedBox(height: 12),
          if (isEditing)
            SettingsDropdownField(
              label: 'Gender',
              value: genderDisplay,
              options: const {
                'male': 'Male',
                'female': 'Female',
                'other': 'Other',
              },
              onChanged: onGenderChanged,
            )
          else
            SettingsReadOnlyRow(
              label: 'Gender',
              value: _genderLabel[genderDisplay] ?? genderDisplay,
            ),
          if (profile.age != null) ...[
            const SizedBox(height: 12),
            SettingsReadOnlyRow(
              label: 'Age',
              value: '${profile.age} years',
            ),
          ],
        ],
      ),
    );
  }
}
