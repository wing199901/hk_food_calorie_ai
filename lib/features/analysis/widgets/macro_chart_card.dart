import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import 'chart_card.dart';

class MacroChartCard extends StatefulWidget {
  final List<Map<String, dynamic>> weeklyData;
  final DateTime currentWeekStart;

  const MacroChartCard({
    super.key,
    required this.weeklyData,
    required this.currentWeekStart,
  });

  @override
  State<MacroChartCard> createState() => _MacroChartCardState();
}

class _MacroChartCardState extends State<MacroChartCard> {
  int? _selectedMacroIndex;

  void _handleMacroTap(int index) {
    if (index < widget.weeklyData.length) {
      setState(() {
        _selectedMacroIndex = (_selectedMacroIndex == index) ? null : index;
      });
    }
  }

  double _niceInterval(double maxY) {
    if (maxY <= 0) return 1;
    final rough = maxY / 4;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final residual = rough / mag;
    double nice;
    if (residual <= 1.5) {
      nice = 1;
    } else if (residual <= 3) {
      nice = 2;
    } else if (residual <= 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * mag;
  }

  LineChartBarData _macroLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) =>
            FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyData = widget.weeklyData;
    final currentWeekStart = widget.currentWeekStart;

    final maxMacro = weeklyData.fold<int>(0, (max, d) {
      final total =
          (d['protein'] as int) + (d['carbs'] as int) + (d['fat'] as int);
      return total > max ? total : max;
    });
    final maxY = (maxMacro * 1.3).ceilToDouble();

    final totalProtein = weeklyData.fold<int>(
      0,
      (s, d) => s + (d['protein'] as int),
    );
    final totalCarbs = weeklyData.fold<int>(
      0,
      (s, d) => s + (d['carbs'] as int),
    );
    final totalFat = weeklyData.fold<int>(0, (s, d) => s + (d['fat'] as int));
    final totalMacro = totalProtein + totalCarbs + totalFat;

    final weekEnd = currentWeekStart.add(const Duration(days: 6));
    final String macroDateRange;
    if (_selectedMacroIndex != null &&
        _selectedMacroIndex! < weeklyData.length) {
      final selectedDate =
          weeklyData[_selectedMacroIndex!]['fullDate'] as DateTime;
      macroDateRange = DateFormat('EEE, dd MMM').format(selectedDate);
    } else {
      macroDateRange =
          '${DateFormat('dd MMM').format(currentWeekStart)} \u2013 ${DateFormat('dd MMM').format(weekEnd)}';
    }

    return ChartCard(
      title: 'Macronutrient Trends (P/C/F)',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            macroDateRange,
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            '${totalMacro}g',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      summary: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartProtein,
                label: 'Protein',
                value: '${totalProtein}g',
              ),
            ),
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartCarbs,
                label: 'Carbs',
                value: '${totalCarbs}g',
              ),
            ),
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartFat,
                label: 'Fat',
                value: '${totalFat}g',
              ),
            ),
          ],
        ),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            maxY: maxY > 0 ? maxY : 100,
            lineBarsData: [
              _macroLine(
                weeklyData
                    .map((d) => (d['protein'] as int).toDouble())
                    .toList(),
                AppTheme.chartProtein,
              ),
              _macroLine(
                weeklyData.map((d) => (d['carbs'] as int).toDouble()).toList(),
                AppTheme.chartCarbs,
              ),
              _macroLine(
                weeklyData.map((d) => (d['fat'] as int).toDouble()).toList(),
                AppTheme.chartFat,
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    const dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                    final i = value.toInt();
                    if (i < 0 || i >= weeklyData.length) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dowLabels[i % 7],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    );
                  },
                  reservedSize: 24,
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: _niceInterval(maxY > 0 ? maxY : 100),
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == meta.min) {
                      return const SizedBox();
                    }
                    return Text(
                      '${value.toInt()}g',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.mutedForeground,
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.chartGrid,
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: AppTheme.chartGrid,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
                HorizontalLine(
                  y: maxY > 0 ? maxY : 100,
                  color: AppTheme.chartGrid,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ],
              verticalLines: [
                if (_selectedMacroIndex != null)
                  VerticalLine(
                    x: _selectedMacroIndex!.toDouble(),
                    color: AppTheme.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
              ],
            ),
            lineTouchData: LineTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent &&
                    response?.lineBarSpots != null &&
                    response!.lineBarSpots!.isNotEmpty) {
                  _handleMacroTap(response.lineBarSpots!.first.x.toInt());
                }
              },
              touchTooltipData: LineTouchTooltipData(
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 0,
                getTooltipColor: (_) => Colors.transparent,
                getTooltipItems: (spots) => spots.map((_) => null).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
