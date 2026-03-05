import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';

class HealthScoresCard extends ConsumerWidget {
  const HealthScoresCard({super.key});

  static const _defaultWeight = 70.0;
  static const _defaultHeight = 175.0;
  static const _defaultWaistline = 80.0;

  double _calculateBMI(UserProfile p) {
    final w = p.weight ?? _defaultWeight;
    final h = p.height ?? _defaultHeight;
    return double.parse((w / ((h / 100) * (h / 100))).toStringAsFixed(1));
  }

  double _calculateWHtR(UserProfile p) {
    final waist = p.waistline ?? _defaultWaistline;
    final h = p.height ?? _defaultHeight;
    return double.parse((waist / h).toStringAsFixed(2));
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String _whtrCategory(double r) {
    if (r < 0.4) return 'Slim';
    if (r < 0.5) return 'Healthy';
    if (r < 0.6) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppTheme.chartWeight;
    if (bmi < 25) return AppTheme.primary;
    if (bmi < 30) return AppTheme.warning;
    return AppTheme.destructive;
  }

  Color _whtrColor(double r) {
    if (r < 0.4) return AppTheme.chartWeight;
    if (r < 0.5) return AppTheme.primary;
    if (r < 0.6) return AppTheme.warning;
    return AppTheme.destructive;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.read(storageProvider).getUserProfile();
    final bmi = _calculateBMI(profile);
    final whtr = _calculateWHtR(profile);
    final tee = StorageService.calculateTEE(profile);

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
          const Row(
            children: [
              Icon(Icons.favorite, color: AppTheme.destructive, size: 20),
              SizedBox(width: 8),
              Text(
                'Health Scores',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _scoreCard(
                  label: 'BMI',
                  value: '$bmi',
                  subtitle: _bmiCategory(bmi),
                  color: _bmiColor(bmi),
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreCard(
                  label: 'WHtR',
                  value: '$whtr',
                  subtitle: _whtrCategory(whtr),
                  color: _whtrColor(whtr),
                  icon: Icons.straighten,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreCard(
                  label: 'TEE',
                  value: '$tee',
                  subtitle: 'kcal/day',
                  color: AppTheme.accent,
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreCard({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
