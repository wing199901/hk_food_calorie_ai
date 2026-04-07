import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/health_score_utils.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';
import '../widgets/ai_insight_section.dart';

class BmiDetailPage extends ConsumerWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;

  const BmiDetailPage({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(storageProvider).getUserProfile();

    final weeklyMetrics = List<Map<String, dynamic>>.generate(7, (i) {
      final day = currentWeekStart.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      final metric = bodyData
          .where((m) => m.date == key)
          .cast<BodyMetric?>()
          .firstWhere((m) => m != null, orElse: () => null);

      final weight = metric?.weight;
      final bmi =
          metric?.bmi ??
          (weight != null
              ? HealthScoreUtils.calculateBMI(
                  weightKg: weight,
                  heightCm: profile.height,
                )
              : null);

      return {'bmi': bmi};
    });

    final bmiValues = weeklyMetrics.map((e) => e['bmi'] as double?).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Body Mass Index',
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
                title: 'BMI Trend',
                values: bmiValues,
                color: AppTheme.primary,
                valueSuffix: '',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    'About Body Mass Index',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Body Mass Index (BMI) is an indicator of your body fat. It’s calculated from your height and weight, and can tell you whether you are underweight, normal, overweight or obese. It can also help you gauge your risk of diseases that can occur with more body fat.",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.foreground,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "National Heart, Lung, and Blood Institute",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    'Insights & Tips',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Body Mass Index (BMI) is an indicator of your body fat. It’s calculated from your height and weight, and can tell you whether you are underweight, normal, overweight or obese. It can also help you gauge your risk of diseases that can occur with more body fat.",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.foreground,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "National Heart, Lung, and Blood Institute",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AiInsightSection(focus: 'bmi'),
              const SizedBox(height: AppSpacing.lg),
              ShowAllDataButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AllRecordedDataPage(dataType: DataType.bmi),
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
      return ChartCard(
        title: title,
        child: const SizedBox(
          height: 130,
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
          value: '${spots.last.y.toStringAsFixed(2)}$valueSuffix',
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
