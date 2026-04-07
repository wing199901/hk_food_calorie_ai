import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class MiniTrendChart extends StatelessWidget {
  final List<double?> values;
  final Color color;

  const MiniTrendChart({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i] != null) {
        spots.add(FlSpot(i.toDouble(), values[i]!));
      }
    }

    if (spots.isEmpty) {
      return const SizedBox(width: 60, height: 30);
    }

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    // Support drawing just one dot within the available range
    if (spots.length == 1) {
      minY -= 1.0;
      maxY += 1.0;
    }

    final span = (maxY - minY).abs();
    final paddedMin = span < 0.1 ? minY - 0.5 : minY - span * 0.1;
    final paddedMax = span < 0.1 ? maxY + 0.5 : maxY + span * 0.1;

    // Determine today's index in the list (assuming values represent 7 days ending near today)
    // The chart runs from index 0 to length-1. We highlight the last available data point.
    // If the data represents the week up to today, the highest X value is today's data.

    return SizedBox(
      width: 60,
      height: 30,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble().clamp(0, 6),
          minY: paddedMin,
          maxY: paddedMax,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: AppTheme.mutedForeground.withValues(alpha: 0.3),
              barWidth: 2.0,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => true, // Show all dots
                getDotPainter: (spot, percent, barData, index) {
                  final isLast = spot.x == barData.spots.last.x;
                  return FlDotCirclePainter(
                    radius: 3.5,
                    color:
                        AppTheme.card, // center color matching card background
                    strokeWidth: 2.5,
                    strokeColor: isLast
                        ? color
                        : AppTheme.mutedForeground.withValues(alpha: 0.3),
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
