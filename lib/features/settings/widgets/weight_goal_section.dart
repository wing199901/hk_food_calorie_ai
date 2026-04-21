import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_number_field.dart';
import 'settings_section.dart';

class WeightGoalSection extends StatelessWidget {
  const WeightGoalSection({
    super.key,
    required this.targetWeightCtrl,
    required this.healthyRangeCaption,
    required this.goalSummaryValue,
    required this.goalSummaryValueColor,
    required this.onTargetWeightChanged,
    required this.onSave,
    required this.isMetric,
  });

  final TextEditingController targetWeightCtrl;
  final String healthyRangeCaption;
  final String goalSummaryValue;
  final Color goalSummaryValueColor;
  final ValueChanged<String> onTargetWeightChanged;
  final VoidCallback onSave;
  final bool isMetric;

  @override
  Widget build(BuildContext context) {
    final targetHint = isMetric ? '65' : '143';

    return SettingsSection(
      icon: Icons.flag_outlined,
      iconColor: AppTheme.primary,
      title: 'Weight Goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsNumberField(
            label: 'Target Weight',
            controller: targetWeightCtrl,
            hint: targetHint,
            unit: isMetric ? 'kg' : 'lbs',
            onChanged: onTargetWeightChanged,
          ),
          const SizedBox(height: 8),
          Text(
            healthyRangeCaption,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mutedForeground,
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
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
                children: [
                  const TextSpan(text: 'Goal: '),
                  TextSpan(
                    text: goalSummaryValue,
                    style: TextStyle(color: goalSummaryValueColor),
                  ),
                ],
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
