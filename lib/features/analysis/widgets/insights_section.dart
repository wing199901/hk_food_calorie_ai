import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';

class InsightsSection extends ConsumerWidget {
  final int weekAverage;
  final int daysOnTarget;
  final int streak;
  final Map<String, int> todayStats;

  const InsightsSection({
    super.key,
    required this.weekAverage,
    required this.daysOnTarget,
    required this.streak,
    required this.todayStats,
  });

  static const _defaultWeight = 70.0;
  static const _defaultHeight = 175.0;

  double _calculateBMI(UserProfile p) {
    final w = p.weight ?? _defaultWeight;
    final h = p.height ?? _defaultHeight;
    return double.parse((w / ((h / 100) * (h / 100))).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = todayStats['target'] ?? 2000;
    final profile = ref.read(storageProvider).getUserProfile();
    final bmi = _calculateBMI(profile);

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
              Icon(Icons.bolt, color: AppTheme.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Insights & Tips',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (weekAverage < target * 0.8 && weekAverage > 0)
            _insightTile(
              AppTheme.warning,
              'Eating a bit too little la~',
              'Your average intake is way below target. Don\'t skip meals — your body needs fuel to function properly!',
            ),
          if (weekAverage > target * 1.2)
            _insightTile(
              AppTheme.accent,
              'Calories a bit high today la~ 🫣',
              'Your average intake is above your TEE. Maybe cut down on the milk tea and egg tarts a bit?',
            ),
          if (bmi >= 25)
            _insightTile(
              AppTheme.warning,
              'BMI is on the higher side',
              'Your BMI is ${bmi.toStringAsFixed(1)} — try swapping fried foods for steamed ones. Small changes add up!',
            ),
          if (bmi < 18.5)
            _insightTile(
              AppTheme.chartWeight,
              'You\'re a bit underweight right now',
              'BMI is ${bmi.toStringAsFixed(1)}. Make sure you\'re eating enough protein and healthy fats!',
            ),
          _insightTile(
            AppTheme.secondary,
            'What is TEE?',
            'Total Energy Expenditure — it\'s how many calories your body burns daily. Match your intake to this number for maintenance.',
            icon: Icons.info_outline,
          ),
          _insightTile(
            AppTheme.primary,
            'Protein is your best friend 💪',
            'Add a source of protein to every meal — chicken breast, eggs, tofu. Keeps you full and helps build muscle!',
          ),
          if (daysOnTarget >= 5)
            _insightTile(
              AppTheme.primary,
              '🎉 So consistent this week!',
              'You hit your TEE target $daysOnTarget out of 7 days — keep it up la!',
            ),
          if (streak >= 3)
            _insightTile(
              AppTheme.accent,
              '🔥 $streak-day streak! On fire!',
              'You\'ve been tracking for $streak days straight. That\'s some serious discipline!',
            ),
        ],
      ),
    );
  }

  Widget _insightTile(
    Color color,
    String title,
    String body, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2),
                child: Icon(icon, size: 16, color: color),
              )
            else
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 12, top: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
