import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';

class WeightDetailPage extends StatelessWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;
  final double? profileWeight;

  const WeightDetailPage({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
    this.profileWeight,
  });

  @override
  Widget build(BuildContext context) {
    final weeklyMetrics = List<Map<String, dynamic>>.generate(7, (i) {
      final day = currentWeekStart.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      final metric = bodyData
          .where((m) => m.date == key)
          .cast<BodyMetric?>()
          .firstWhere((m) => m != null, orElse: () => null);

      return {'weight': metric?.weight};
    });

    final weightValues = weeklyMetrics
        .map((e) => e['weight'] as double?)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Weight',
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
              _trendLineCard(
                title: 'Weight Trend',
                values: weightValues,
                color: AppTheme.chartWeight,
                valueSuffix: 'kg',
              ),
              const SizedBox(height: AppSpacing.lg),
              ShowAllDataButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AllRecordedDataPage(dataType: DataType.weight),
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

  Widget _trendLineCard({
    required String title,
    required List<double?> values,
    required Color color,
    required String valueSuffix,
  }) {
    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null && v > 0) {
        spots.add(FlSpot(i.toDouble(), v));
      }
    }

    if (spots.isEmpty) {
      final fallback = profileWeight != null
          ? '${profileWeight!.toStringAsFixed(1)}$valueSuffix'
          : '--$valueSuffix';
      return ChartCard(
        title: title,
        summary: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: SummaryChip(color: color, label: 'Current', value: fallback),
        ),
        child: const SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No data this week',
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
          ),
        ),
      );
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final span = (maxY - minY).abs();
    final paddedMin = span < 0.5 ? minY - 0.5 : minY - span * 0.2;
    final paddedMax = span < 0.5 ? maxY + 0.5 : maxY + span * 0.2;

    return ChartCard(
      title: title,
      summary: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: SummaryChip(
          color: color,
          label: 'Latest',
          value: '${spots.last.y.toStringAsFixed(1)}$valueSuffix',
        ),
      ),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: 6,
            minY: paddedMin,
            maxY: paddedMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2,
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.12),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 3,
                    color: color,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
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
                    const dow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                    final i = value.toInt();
                    if (i < 0 || i >= dow.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dow[i],
                        style: const TextStyle(
                          fontSize: 12,
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
