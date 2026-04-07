import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';
import 'mini_trend_chart.dart';

class WeightPreview extends StatelessWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;
  final double? profileWeight;

  const WeightPreview({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
    this.profileWeight,
  });

  String _formatValue(double? value, {int fraction = 1}) {
    if (value == null) return '--';
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(fraction);
  }

  @override
  Widget build(BuildContext context) {
    // Collect 7 body metrics for the week range
    final values = List<double?>.generate(7, (i) {
      final day = currentWeekStart.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final metric = bodyData.where((m) => m.date == key).lastOrNull;
      return metric?.weight;
    });

    // Determine the active display weight
    double? displayWeight;
    for (int i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) {
        displayWeight = values[i];
        break;
      }
    }
    displayWeight ??= profileWeight;

    // Fallback logic if there is no data in this week, but we have a profile weight
    if (displayWeight != null && !values.any((v) => v != null)) {
      // Create at least one dot to display
      values[6] = displayWeight;
    }

    return Stack(
      children: [
        // Left side: Large weight value
        Align(
          alignment: Alignment.bottomLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(displayWeight),
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
                  'kg',
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
        Align(
          alignment: Alignment.centerRight,
          child: MiniTrendChart(values: values, color: AppTheme.secondary),
        ),
      ],
    );
  }
}
