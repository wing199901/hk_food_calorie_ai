import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';
import '../../../shared/utils/health_score_utils.dart';
import 'mini_trend_chart.dart';

class BmiPreview extends StatelessWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;
  final double? profileHeight;
  final double? profileWeight;

  const BmiPreview({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
    this.profileHeight,
    this.profileWeight,
  });

  String _formatValue(double? value, {int fraction = 1}) {
    if (value == null) return '--';
    return value.toStringAsFixed(fraction);
  }

  @override
  Widget build(BuildContext context) {
    // Generate recent 7 points if available
    final values = List<double?>.generate(7, (i) {
      final day = currentWeekStart.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final metric = bodyData.where((m) => m.date == key).lastOrNull;
      if (metric != null) {
        double? bmi = metric.bmi;
        if (bmi == null && metric.weight != null && profileHeight != null) {
          bmi = HealthScoreUtils.calculateBMI(
            weightKg: metric.weight!,
            heightCm: profileHeight!,
          );
        }
        return bmi;
      }
      return null;
    });

    double? displayBmi;
    for (int i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) {
        displayBmi = values[i];
        break;
      }
    }

    // fallback to profile profileWeight & profileHeight
    if (displayBmi == null && profileWeight != null && profileHeight != null) {
      displayBmi = HealthScoreUtils.calculateBMI(
        weightKg: profileWeight!,
        heightCm: profileHeight!,
      );
    }

    if (displayBmi != null && !values.any((v) => v != null)) {
      values[6] = displayBmi;
    }

    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(displayBmi),
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
                  'BMI',
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
        Align(
          alignment: Alignment.centerRight,
          child: MiniTrendChart(
            values: values,
            color: AppTheme.primary, // using primary color (purple/pinkish)
          ),
        ),
      ],
    );
  }
}
