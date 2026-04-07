import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import '../widgets/ai_insight_section.dart';
import 'all_recorded_data_page.dart';

class MacronutrientDetailPage extends StatefulWidget {
  final List<Map<String, dynamic>> weeklyData;
  final DateTime currentWeekStart;

  const MacronutrientDetailPage({
    super.key,
    required this.weeklyData,
    required this.currentWeekStart,
  });

  @override
  State<MacronutrientDetailPage> createState() =>
      _MacronutrientDetailPageState();
}

class _MacronutrientDetailPageState extends State<MacronutrientDetailPage> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.weeklyData.isNotEmpty
        ? widget.weeklyData.length - 1
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyData = widget.weeklyData;

    final totalProtein = weeklyData.fold<int>(
      0,
      (sum, d) => sum + (d['protein'] as int),
    );
    final totalCarbs = weeklyData.fold<int>(
      0,
      (sum, d) => sum + (d['carbs'] as int),
    );
    final totalFat = weeklyData.fold<int>(
      0,
      (sum, d) => sum + (d['fat'] as int),
    );
    final totalMacro = totalProtein + totalCarbs + totalFat;

    final selected =
        (_selectedIndex != null && _selectedIndex! < weeklyData.length)
        ? weeklyData[_selectedIndex!]
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Macronutrients',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Column(
            children: [
              _macroStackedChartCard(
                totalProtein: totalProtein,
                totalCarbs: totalCarbs,
                totalFat: totalFat,
                totalMacro: totalMacro,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (selected != null) _selectedBreakdownCard(selected),
              if (selected != null) const SizedBox(height: AppSpacing.lg),
              _dailyRatioCard(weeklyData),
              const SizedBox(height: AppSpacing.lg),
              const AiInsightSection(focus: 'macronutrients'),
              const SizedBox(height: AppSpacing.lg),
              ShowAllDataButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AllRecordedDataPage(dataType: DataType.macro),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroStackedChartCard({
    required int totalProtein,
    required int totalCarbs,
    required int totalFat,
    required int totalMacro,
  }) {
    final weeklyData = widget.weeklyData;
    final maxDaily = weeklyData.fold<int>(0, (max, d) {
      final sum =
          (d['protein'] as int) + (d['carbs'] as int) + (d['fat'] as int);
      return sum > max ? sum : max;
    });

    final maxYRaw = maxDaily <= 0 ? 100 : (maxDaily * 1.25).toDouble();
    final maxY = ((maxYRaw / 50).ceil() * 50).toDouble();
    final midY = maxY / 2;

    return ChartCard(
      title: '7-Day Macro Distribution',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('dd MMM').format(widget.currentWeekStart)} – ${DateFormat('dd MMM').format(widget.currentWeekStart.add(const Duration(days: 6)))}',
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            '$totalMacro g total',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      summary: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartProtein,
                label: 'Protein',
                value:
                    '${_percent(totalProtein, totalMacro)}% • ${totalProtein}g',
              ),
            ),
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartCarbs,
                label: 'Carbs',
                value: '${_percent(totalCarbs, totalMacro)}% • ${totalCarbs}g',
              ),
            ),
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartFat,
                label: 'Fat',
                value: '${_percent(totalFat, totalMacro)}% • ${totalFat}g',
              ),
            ),
          ],
        ),
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            barGroups: List.generate(weeklyData.length, (i) {
              final protein = (weeklyData[i]['protein'] as int).toDouble();
              final carbs = (weeklyData[i]['carbs'] as int).toDouble();
              final fat = (weeklyData[i]['fat'] as int).toDouble();
              final total = protein + carbs + fat;

              final isSelected = _selectedIndex == i;
              final dimmed = _selectedIndex != null && !isSelected;

              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: total,
                    width: 24,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        protein,
                        dimmed
                            ? AppTheme.chartProtein.withValues(alpha: 0.35)
                            : AppTheme.chartProtein,
                      ),
                      BarChartRodStackItem(
                        protein,
                        protein + carbs,
                        dimmed
                            ? AppTheme.chartCarbs.withValues(alpha: 0.35)
                            : AppTheme.chartCarbs,
                      ),
                      BarChartRodStackItem(
                        protein + carbs,
                        total,
                        dimmed
                            ? AppTheme.chartFat.withValues(alpha: 0.35)
                            : AppTheme.chartFat,
                      ),
                    ],
                  ),
                ],
              );
            }),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
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
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == midY || value == maxY) {
                      return Text(
                        '${value.toInt()}g',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedForeground,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    const dow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                    final i = value.toInt();
                    if (i < 0 || i >= dow.length) return const SizedBox();
                    final isSelected = _selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dow[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.foreground
                              : AppTheme.mutedForeground,
                        ),
                      ),
                    );
                  },
                ),
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
                  y: maxY,
                  color: AppTheme.chartGrid,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ],
              verticalLines: [
                if (_selectedIndex != null)
                  VerticalLine(
                    x: _selectedIndex!.toDouble(),
                    color: AppTheme.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
              ],
            ),
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent && response?.spot != null) {
                  setState(() {
                    final idx = response!.spot!.touchedBarGroupIndex;
                    _selectedIndex = _selectedIndex == idx ? null : idx;
                  });
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

  Widget _selectedBreakdownCard(Map<String, dynamic> day) {
    final date = day['fullDate'] as DateTime;
    final protein = day['protein'] as int;
    final carbs = day['carbs'] as int;
    final fat = day['fat'] as int;
    final total = protein + carbs + fat;

    return _sectionCard(
      title: 'Selected Day Split',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEE, dd MMM').format(date),
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ratioRow(
            color: AppTheme.chartProtein,
            label: 'Protein',
            value: '$protein g',
            ratio: _percent(protein, total),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ratioRow(
            color: AppTheme.chartCarbs,
            label: 'Carbs',
            value: '$carbs g',
            ratio: _percent(carbs, total),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ratioRow(
            color: AppTheme.chartFat,
            label: 'Fat',
            value: '$fat g',
            ratio: _percent(fat, total),
          ),
        ],
      ),
    );
  }

  Widget _dailyRatioCard(List<Map<String, dynamic>> weeklyData) {
    return _sectionCard(
      title: 'Daily Ratio Breakdown',
      child: Column(
        children: [
          for (int i = 0; i < weeklyData.length; i++)
            _dailyRatioRow(
              day: weeklyData[i],
              isLast: i == weeklyData.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _dailyRatioRow({
    required Map<String, dynamic> day,
    required bool isLast,
  }) {
    final date = day['fullDate'] as DateTime;
    final protein = day['protein'] as int;
    final carbs = day['carbs'] as int;
    final fat = day['fat'] as int;
    final total = protein + carbs + fat;

    final proteinPct = _percent(protein, total);
    final carbsPct = _percent(carbs, total);
    final fatPct = _percent(fat, total);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('EEE').format(date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: _stackPreview(
              proteinPct: proteinPct,
              carbsPct: carbsPct,
              fatPct: fatPct,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 4,
            child: Text(
              'P $proteinPct%  C $carbsPct%  F $fatPct%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stackPreview({
    required int proteinPct,
    required int carbsPct,
    required int fatPct,
  }) {
    final proteinFlex = proteinPct == 0 ? 1 : proteinPct;
    final carbsFlex = carbsPct == 0 ? 1 : carbsPct;
    final fatFlex = fatPct == 0 ? 1 : fatPct;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: proteinFlex,
              child: Container(color: AppTheme.chartProtein),
            ),
            Expanded(
              flex: carbsFlex,
              child: Container(color: AppTheme.chartCarbs),
            ),
            Expanded(
              flex: fatFlex,
              child: Container(color: AppTheme.chartFat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratioRow({
    required Color color,
    required String label,
    required String value,
    required int ratio,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '$ratio% • $value',
          style: const TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  int _percent(int value, int total) {
    if (total <= 0) return 0;
    return ((value / total) * 100).round();
  }
}
