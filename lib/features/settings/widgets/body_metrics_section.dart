import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_section.dart';
import 'settings_number_field.dart';
import 'settings_dropdown_field.dart';

class BodyMetricsSection extends StatelessWidget {
  const BodyMetricsSection({
    super.key,
    required this.weightCtrl,
    required this.preferredWeightCtrl,
    required this.heightCtrl,
    required this.waistlineCtrl,
    required this.activityLevel,
    required this.intakeMin,
    required this.intakeMax,
    required this.onActivityChanged,
    required this.onUpdateToday,
    required this.isMetric,
  });

  final TextEditingController weightCtrl;
  final TextEditingController preferredWeightCtrl;
  final TextEditingController heightCtrl;
  final TextEditingController waistlineCtrl;
  final String activityLevel;
  final int intakeMin;
  final int intakeMax;
  final ValueChanged<String> onActivityChanged;
  final VoidCallback onUpdateToday;
  final bool isMetric;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      icon: Icons.monitor_weight_outlined,
      iconColor: AppTheme.accent,
      title: 'Body Metrics',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SettingsNumberField(
                  label: 'Weight (${isMetric ? 'kg' : 'lbs'})',
                  controller: weightCtrl,
                  hint: isMetric ? '70' : '154',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SettingsNumberField(
                  label: 'Height (${isMetric ? 'cm' : 'in'})',
                  controller: heightCtrl,
                  hint: isMetric ? '175' : '69',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsNumberField(
            label: 'Waistline (${isMetric ? 'cm' : 'in'})',
            controller: waistlineCtrl,
            hint: isMetric ? '80' : '31',
          ),
          const SizedBox(height: 12),
          SettingsNumberField(
            label: 'Preferred Weight (${isMetric ? 'kg' : 'lbs'})',
            controller: preferredWeightCtrl,
            hint: isMetric ? '65' : '143',
          ),
          const SizedBox(height: 12),
          SettingsDropdownField(
            label: 'Activity Level',
            value: activityLevel,
            options: const {
              'sedentary': 'Sedentary (little/no exercise)',
              'light': 'Light (1-3 days/week)',
              'moderate': 'Moderate (3-5 days/week)',
              'active': 'Active (6-7 days/week)',
              'very-active': 'Very Active (2x per day)',
            },
            onChanged: onActivityChanged,
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
              intakeMin == intakeMax
                  ? 'Daily target: $intakeMax kcal'
                  : 'Daily target range: $intakeMin-$intakeMax kcal',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onUpdateToday,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                'Update',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
