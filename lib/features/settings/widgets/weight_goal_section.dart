import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/weight_goal_selector.dart';
import 'settings_number_field.dart';
import 'settings_section.dart';

class WeightGoalSection extends StatelessWidget {
  const WeightGoalSection({
    super.key,
    required this.goalWeightDeltaCtrl,
    required this.weightGoal,
    required this.targetPreview,
    required this.onWeightGoalChanged,
    required this.onGoalWeightDeltaChanged,
    required this.onSave,
    required this.isMetric,
  });

  final TextEditingController goalWeightDeltaCtrl;
  final String weightGoal;
  final String targetPreview;
  final ValueChanged<String> onWeightGoalChanged;
  final ValueChanged<String> onGoalWeightDeltaChanged;
  final VoidCallback onSave;
  final bool isMetric;

  @override
  Widget build(BuildContext context) {
    final goalHint = isMetric ? '5' : '11';

    return SettingsSection(
      icon: Icons.flag_outlined,
      iconColor: AppTheme.primary,
      title: 'Weight Goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Goal Direction',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          WeightGoalSelector(
            value: weightGoal,
            onChanged: onWeightGoalChanged,
          ),
          const SizedBox(height: 12),
          SettingsNumberField(
            label: 'Change Amount',
            controller: goalWeightDeltaCtrl,
            hint: goalHint,
            unit: isMetric ? 'kg' : 'lbs',
            enabled: weightGoal != 'maintain',
            onChanged: onGoalWeightDeltaChanged,
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
              targetPreview,
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
              onPressed: onSave,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                'Save Goal',
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
