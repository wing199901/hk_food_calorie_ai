import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'chart_card.dart';

class EnergyChartCard extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> weeklyData;
  final DateTime currentWeekStart;

  const EnergyChartCard({
    super.key,
    required this.weeklyData,
    required this.currentWeekStart,
  });

  @override
  ConsumerState<EnergyChartCard> createState() => _EnergyChartCardState();
}

class _EnergyChartCardState extends ConsumerState<EnergyChartCard> {
  int? _selectedBarIndex;

  void _handleBarTap(int index) {
    if (index < widget.weeklyData.length) {
      setState(() {
        _selectedBarIndex = (_selectedBarIndex == index) ? null : index;
      });
    }
  }

  Widget? _buildSelectedDayHourlyChart() {
    if (_selectedBarIndex == null ||
        _selectedBarIndex! >= widget.weeklyData.length) {
      return null;
    }
    final d = widget.weeklyData[_selectedBarIndex!];
    final date = d['fullDate'] as DateTime;

    final meals = ref.read(storageProvider).getMealsForDate(date);
    final hourlyCalories = List.filled(24, 0);
    for (final meal in meals) {
      final mealTime = DateTime.fromMillisecondsSinceEpoch(meal.timestamp);
      hourlyCalories[mealTime.hour] += meal.calories;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              maxY: 2000,
              barGroups: List.generate(24, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: hourlyCalories[i].toDouble(),
                      color: AppTheme.primary,
                      width: 8,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(2),
                      ),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 6,
                    getTitlesWidget: (value, meta) {
                      final h = value.toInt();
                      if (h % 6 != 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          h.toString().padLeft(2, '0'),
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
                    reservedSize: 16,
                    interval: 1000,
                    getTitlesWidget: (value, meta) {
                      String label;
                      if (value == 0) {
                        label = '0';
                      } else if (value == 1000) {
                        label = '1k';
                      } else if (value == 2000) {
                        label = '2k';
                      } else {
                        return const SizedBox();
                      }
                      return Text(
                        label,
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
                horizontalInterval: 500,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.chartGrid,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: AppTheme.chartGrid,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  HorizontalLine(
                    y: 2000,
                    color: AppTheme.chartGrid,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyData = widget.weeklyData;
    final currentWeekStart = widget.currentWeekStart;

    final totalCal = weeklyData.fold<int>(
      0,
      (s, d) => s + (d['calories'] as int),
    );
    final avgTarget = weeklyData.isNotEmpty
        ? weeklyData.fold<int>(0, (s, d) => s + (d['target'] as int)) ~/
              weeklyData.length
        : 0;

    final maxY = (((avgTarget > 0 ? avgTarget : 2000) / 2000).ceil() * 2000)
        .toDouble();
    final midY = maxY / 2;
    final gridInterval = maxY / 4;

    String fmtY(double v) {
      if (v == 0) return '0';
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }

    const dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final weekEnd = currentWeekStart.add(const Duration(days: 6));
    final String dateRange;
    if (_selectedBarIndex != null && _selectedBarIndex! < weeklyData.length) {
      final selectedDate =
          weeklyData[_selectedBarIndex!]['fullDate'] as DateTime;
      dateRange = DateFormat('EEE, dd MMM').format(selectedDate);
    } else {
      dateRange =
          '${DateFormat('dd MMM').format(currentWeekStart)} – ${DateFormat('dd MMM').format(weekEnd)}';
    }

    return ChartCard(
      title: 'Energy Intake',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateRange,
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            '$totalCal kcal',
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
                color: AppTheme.primary,
                label: 'Consumed',
                value: '$totalCal kcal',
              ),
            ),
            Expanded(
              child: SummaryChip(
                color: AppTheme.accent,
                label: 'TEE',
                value: '$avgTarget kcal',
              ),
            ),
          ],
        ),
      ),
      expandedDetail: _buildSelectedDayHourlyChart(),
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: List.generate(weeklyData.length, (i) {
              final d = weeklyData[i];
              final cal = (d['calories'] as int).toDouble();
              final target = (d['target'] as int).toDouble();
              final isSelected = _selectedBarIndex == i;
              final dimmed = _selectedBarIndex != null && !isSelected;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: cal,
                    color: dimmed
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : AppTheme.primary,
                    width: 24,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: target,
                      color: dimmed
                          ? AppTheme.accent.withValues(alpha: 0.08)
                          : AppTheme.accent.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              );
            }),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= weeklyData.length) {
                      return const SizedBox();
                    }
                    final isSelected = _selectedBarIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dowLabels[i % 7],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.black87
                              : AppTheme.mutedForeground,
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
                  reservedSize: 16,
                  interval: gridInterval,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == midY || value == maxY) {
                      return Text(
                        fmtY(value),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.mutedForeground,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: gridInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.chartGrid,
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: AppTheme.chartGrid,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
                HorizontalLine(
                  y: maxY,
                  color: AppTheme.chartGrid,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ],
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent && response?.spot != null) {
                  _handleBarTap(response!.spot!.touchedBarGroupIndex);
                }
              },
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 0,
                getTooltipColor: (_) => Colors.transparent,
                getTooltipItem: (_, _, _, _) => null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
