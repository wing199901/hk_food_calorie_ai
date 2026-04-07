import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import 'mini_energy_bars.dart';

class EnergyPreview extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final int weekAverage;
  final int daysOnTarget;
  final Map<String, dynamic>? todayStats;

  const EnergyPreview({
    super.key,
    required this.weeklyData,
    required this.weekAverage,
    required this.daysOnTarget,
    this.todayStats,
  });

  @override
  Widget build(BuildContext context) {
    final int calories = todayStats != null
        ? ((todayStats!['consumed'] as num?)?.toInt() ?? 0)
        : 0;
    // Format with commas like 1,286
    final formattedCalories = calories.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left side: Large value
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formattedCalories,
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Padding(
                padding: EdgeInsets.only(
                  bottom: 2,
                ), // visually align unit closely with bottom
                child: Text(
                  'kcal',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Right side: Chart
        const SizedBox(width: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 80,
            height: 48,
            child: MiniEnergyBars(weeklyData: weeklyData),
          ),
        ),
      ],
    );
  }
}
