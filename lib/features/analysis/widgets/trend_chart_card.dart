import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import 'chart_card.dart';

class TrendChartCard extends StatelessWidget {
  final String title;
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String valueSuffix;
  final int fractionDigits;

  const TrendChartCard({
    super.key,
    required this.title,
    required this.values,
    required this.labels,
    required this.color,
    required this.valueSuffix,
    this.fractionDigits = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return ChartCard(
        title: title,
        child: const SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No data available',
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    final minY = spots.map((s) => s.y).reduce(math.min);
    final maxY = spots.map((s) => s.y).reduce(math.max);
    final span = (maxY - minY).abs();
    final paddedMin = span < 0.5 ? minY - 0.5 : minY - span * 0.2;
    final paddedMax = span < 0.5 ? maxY + 0.5 : maxY + span * 0.2;

    double minX = 0;
    double maxX = math.max(0, values.length - 1).toDouble();

    // If only one date, center the dot
    if (spots.length == 1) {
      minX = -0.5;
      maxX = 0.5;
    }

    return ChartCard(
      title: title,
      summary: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: SummaryChip(
          color: color,
          label: 'Latest',
          value: '${spots.last.y.toStringAsFixed(fractionDigits)}$valueSuffix',
        ),
      ),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: paddedMin,
            maxY: paddedMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2.5,
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.12),
                ),
                dotData: FlDotData(
                  show: true,
                  // Show all dots
                  checkToShowDot: (spot, barData) => true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: color,
                      ),
                ),
              ),
            ],
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.chartGrid,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    // fl_chart might request floats if we mess with minX/maxX depending on range, just safe check
                    if (value != i.toDouble() || i < 0 || i >= labels.length) {
                      return const SizedBox();
                    }

                    final label = labels[i];
                    String formatted = label;
                    if (label.contains('-')) {
                      try {
                        final dt = DateTime.parse(label);
                        formatted = DateFormat('d MMM').format(dt);
                      } catch (_) {}
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        formatted,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
