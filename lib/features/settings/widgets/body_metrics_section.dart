import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_section.dart';
import 'settings_number_field.dart';

class BodyMetricsSection extends StatelessWidget {
  const BodyMetricsSection({
    super.key,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.waistlineCtrl,
    required this.onUpdateToday,
    required this.isMetric,
    this.onWeightChanged,
  });

  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;
  final TextEditingController waistlineCtrl;
  final VoidCallback onUpdateToday;
  final bool isMetric;
  final ValueChanged<String>? onWeightChanged;

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
                  label: 'Weight',
                  controller: weightCtrl,
                  hint: isMetric ? '70' : '154',
                  unit: isMetric ? 'kg' : 'lbs',
                  labelMinHeight: 40,
                  onChanged: onWeightChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SettingsNumberField(
                  label: 'Height',
                  controller: heightCtrl,
                  hint: isMetric ? '175' : '5.7',
                  unit: isMetric ? 'cm' : 'ft',
                  labelMinHeight: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsNumberField(
            label: 'Waistline',
            controller: waistlineCtrl,
            hint: isMetric ? '80' : '31',
            unit: isMetric ? 'cm' : 'in',
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
