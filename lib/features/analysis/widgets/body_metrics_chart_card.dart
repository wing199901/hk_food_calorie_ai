import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/body_metric.dart';
import '../../../core/theme/app_theme.dart';
import 'chart_card.dart';

class BodyMetricsChartCard extends ConsumerStatefulWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;

  const BodyMetricsChartCard({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
  });

  @override
  ConsumerState<BodyMetricsChartCard> createState() =>
      _BodyMetricsChartCardState();
}

class _BodyMetricsChartCardState extends ConsumerState<BodyMetricsChartCard> {
  int? _selectedBodyIndex;

  void _handleBodyTap(int index) {
    if (index < 7) {
      setState(() {
        _selectedBodyIndex = (_selectedBodyIndex == index) ? null : index;
      });
    }
  }

  Widget? _buildSelectedBodyDetail(List<Map<String, dynamic>> chartData) {
    if (_selectedBodyIndex == null || _selectedBodyIndex! >= chartData.length) {
      return null;
    }
    final d = chartData[_selectedBodyIndex!];
    final weight = d['weight'] as double?;
    final waistline = d['waistline'] as double?;
    final dateStr = d['dateStr'] as String;
    final hasWeight = weight != null && weight > 0;
    final hasWaist = waistline != null && waistline > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppTheme.mutedForeground,
                  fontSize: 13,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedBodyIndex = null),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hasWeight
                ? '${weight.toStringAsFixed(1)} kg'
                : (hasWaist
                    ? '${waistline.toStringAsFixed(1)} cm'
                    : 'No data'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              DetailChip(
                label: 'Weight',
                value: hasWeight ? '${weight.toStringAsFixed(1)} kg' : '—',
                color: AppTheme.chartWeight,
              ),
              const SizedBox(width: 12),
              DetailChip(
                label: 'Waist',
                value: hasWaist ? '${waistline.toStringAsFixed(1)} cm' : '—',
                color: AppTheme.chartWaist,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyData = widget.bodyData;
    final currentWeekStart = widget.currentWeekStart;

    final fmt = DateFormat('yyyy-MM-dd');
    final entryMap = <String, Map<String, double>>{};

    for (final m in bodyData) {
      entryMap[m.date] = {
        'weight': m.weight ?? 0,
        'waistline': m.waistline ?? 0,
      };
    }

    if (entryMap.isEmpty) {
      final profile = ref.read(storageProvider).getUserProfile();
      final w = profile.weight ?? 0;
      final wl = profile.waistline ?? 0;
      if (w > 0 || wl > 0) {
        entryMap[fmt.format(DateTime.now())] = {
          'weight': w.toDouble(),
          'waistline': wl.toDouble(),
        };
      }
    }

    final chartData = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final d = currentWeekStart.add(Duration(days: i));
      final key = fmt.format(d);
      final data = entryMap[key];
      chartData.add({
        'dateStr': DateFormat('dd/MM').format(d),
        'weight': data?['weight'],
        'waistline': data?['waistline'],
      });
    }

    final weightSpots = <FlSpot>[];
    final waistSpots = <FlSpot>[];
    for (int i = 0; i < chartData.length; i++) {
      if (chartData[i]['weight'] != null && chartData[i]['weight'] > 0) {
        weightSpots.add(
          FlSpot(i.toDouble(), (chartData[i]['weight'] as double)),
        );
      }
      if (chartData[i]['waistline'] != null && chartData[i]['waistline'] > 0) {
        waistSpots.add(
          FlSpot(i.toDouble(), (chartData[i]['waistline'] as double)),
        );
      }
    }

    final latestWeight = weightSpots.isNotEmpty
        ? weightSpots.last.y.toStringAsFixed(1)
        : '—';
    final latestWaist = waistSpots.isNotEmpty
        ? waistSpots.last.y.toStringAsFixed(1)
        : '—';
    final hasAnyWeight = weightSpots.isNotEmpty;

    final weekEnd = currentWeekStart.add(const Duration(days: 6));
    final String bodyDateRange;
    if (_selectedBodyIndex != null && _selectedBodyIndex! < chartData.length) {
      final selectedDate = currentWeekStart.add(
        Duration(days: _selectedBodyIndex!),
      );
      bodyDateRange = DateFormat('EEE, dd MMM').format(selectedDate);
    } else {
      bodyDateRange =
          '${DateFormat('dd MMM').format(currentWeekStart)} \u2013 ${DateFormat('dd MMM').format(weekEnd)}';
    }

    return ChartCard(
      title: 'Body Metrics History',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bodyDateRange,
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            hasAnyWeight ? '$latestWeight kg' : '$latestWaist cm',
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
                color: AppTheme.chartWeight,
                label: 'Weight',
                value: '$latestWeight kg',
              ),
            ),
            Expanded(
              child: SummaryChip(
                color: AppTheme.chartWaist,
                label: 'Waist',
                value: '$latestWaist cm',
              ),
            ),
          ],
        ),
      ),
      expandedDetail: _buildSelectedBodyDetail(chartData),
      child: SizedBox(
        height: 200,
        child: (weightSpots.isEmpty && waistSpots.isEmpty)
            ? const Center(
                child: Text(
                  'No body data for this week',
                  style: TextStyle(color: AppTheme.mutedForeground),
                ),
              )
            : LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  lineBarsData: [
                    if (weightSpots.isNotEmpty)
                      LineChartBarData(
                        spots: weightSpots,
                        isCurved: true,
                        color: AppTheme.chartWeight,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: AppTheme.chartWeight,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                    if (waistSpots.isNotEmpty)
                      LineChartBarData(
                        spots: waistSpots,
                        isCurved: true,
                        color: AppTheme.chartWaist,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: AppTheme.chartWaist,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const dowLabels = [
                            'S', 'M', 'T', 'W', 'T', 'F', 'S',
                          ];
                          final i = value.toInt();
                          if (i < 0 || i >= chartData.length) {
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
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox();
                          }
                          return Text(
                            value.toStringAsFixed(1),
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
                    ],
                    verticalLines: [
                      if (_selectedBodyIndex != null)
                        VerticalLine(
                          x: _selectedBodyIndex!.toDouble(),
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
                        _handleBodyTap(
                          response.lineBarSpots!.first.x.toInt(),
                        );
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 0,
                      getTooltipColor: (_) => Colors.transparent,
                      getTooltipItems: (spots) =>
                          spots.map((_) => null).toList(),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
