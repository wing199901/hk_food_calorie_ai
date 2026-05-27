import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_time_policy.dart';
import '../../../shared/models/body_metric.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/health_score_utils.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';
import '../widgets/ai_insight_section.dart';

enum _BmiRange { d, w, m, m6, y }

class BmiDetailPage extends ConsumerStatefulWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;

  const BmiDetailPage({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
  });

  @override
  ConsumerState<BmiDetailPage> createState() => _BmiDetailPageState();
}

class _BmiDetailPageState extends ConsumerState<BmiDetailPage> {
  _BmiRange _range = _BmiRange.w;
  int? _selectedSpotIndex;
  List<DateTime> _spotDates = const [];

  // --- Date Helpers ---
  static DateTime _startOfDay(DateTime d) => AppTimePolicy.startOfLocalDay(d);

  static DateTime? _metricDateOnlyLocal(BodyMetric metric) {
    final parsed = AppTimePolicy.parseDateKeyLocal(metric.date);
    if (parsed == null) return null;
    return _startOfDay(parsed);
  }

  static DateTime? _metricLocalTimestamp(BodyMetric metric) {
    final fromCreatedAt = AppTimePolicy.parseTransportTimestampToLocal(
      metric.createdAt,
    );
    if (fromCreatedAt != null) return fromCreatedAt;
    return _metricDateOnlyLocal(metric);
  }

  static DateTime? _metricLocalDay(BodyMetric metric) {
    final ts = _metricLocalTimestamp(metric);
    if (ts == null) return null;
    return _startOfDay(ts);
  }

  static double? _bmiForMetric(BodyMetric metric, double? heightCm) {
    final bmi = metric.bmi;
    if (bmi != null && bmi > 0) return bmi;

    final weight = metric.weight;
    if (weight == null || weight <= 0) return null;

    return HealthScoreUtils.calculateBMI(weightKg: weight, heightCm: heightCm);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(storageSignalProvider);
    final profile = ref.read(storageProvider).getUserProfile();
    final heightCm = profile.height;

    // --- Data Prep ---
    // De-dupe: only keep the latest entry per local day.
    final byDay = <DateTime, BodyMetric>{};
    DateTime? latestDay;
    for (final m in widget.bodyData) {
      final bmi = _bmiForMetric(m, heightCm);
      if (bmi == null || bmi <= 0) continue;

      final day = _metricLocalDay(m);
      if (day == null) continue;

      latestDay = (latestDay == null || day.isAfter(latestDay))
          ? day
          : latestDay;

      final existing = byDay[day];
      if (existing == null) {
        byDay[day] = m;
        continue;
      }

      // Prefer the newest createdAt; fall back to later list order.
      final a = DateTime.tryParse(existing.createdAt ?? '');
      final b = DateTime.tryParse(m.createdAt ?? '');
      if (a == null && b == null) {
        byDay[day] = m;
      } else if (a == null && b != null) {
        byDay[day] = m;
      } else if (a != null && b != null && b.isAfter(a)) {
        byDay[day] = m;
      }
    }

    final daily =
        byDay.entries
            .map(
              (e) => (date: e.key, bmi: _bmiForMetric(e.value, heightCm)!),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final chart = _buildChartSeries(
      latestDay: latestDay,
      daily: daily,
      all: widget.bodyData,
      heightCm: heightCm,
    );

    final spots = chart.spots;
    _spotDates = chart.spotDates;

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
              _rangeToggle(),
              const SizedBox(height: AppSpacing.sm),
              _trendLineCard(
                title: 'BMI Trend',
                spots: spots,
                minX: chart.minX,
                maxX: chart.maxX,
                bottomInterval: chart.bottomInterval,
                bottomTitle: chart.bottomTitle,
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

  // --- Controls ---
  Widget _rangeToggle() {
    const labels = {
      _BmiRange.d: 'D',
      _BmiRange.w: 'W',
      _BmiRange.m: 'M',
      _BmiRange.m6: '6M',
      _BmiRange.y: 'Y',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: CupertinoSlidingSegmentedControl<_BmiRange>(
        groupValue: _range,
        thumbColor: Colors.white,
        backgroundColor: AppTheme.muted,
        children: {
          for (final r in _BmiRange.values)
            r: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              child: Text(
                labels[r]!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: r == _range
                      ? AppTheme.foreground
                      : AppTheme.mutedForeground,
                ),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v == null) return;
          setState(() {
            _range = v;
            _selectedSpotIndex = null;
          });
        },
      ),
    );
  }

  // --- Chart UI ---
  Widget _trendLineCard({
    required String title,
    required List<FlSpot> spots,
    required double minX,
    required double maxX,
    required double bottomInterval,
    required Widget Function(double) bottomTitle,
    required Color color,
    required String valueSuffix,
  }) {
    if (spots.isEmpty) {
      return ChartCard(
        title: title,
        child: const SizedBox(
          height: 130,
          child: Center(
            child: Text(
              'No data in range',
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
          ),
        ),
      );
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final span = (maxY - minY).abs();
    final chartMaxX = maxX + 0.15;
    final paddedMin = span < 0.5 ? minY - 0.5 : minY - span * 0.2;
    final paddedMax = span < 0.5 ? maxY + 0.5 : maxY + span * 0.2;
    final showTooltip =
        _selectedSpotIndex != null && _selectedSpotIndex! < spots.length;
    final selectedIndex = showTooltip ? _selectedSpotIndex : null;
    final barData = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      showingIndicators: selectedIndex != null ? [selectedIndex] : const [],
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
    );

    final tooltipIndicators = selectedIndex != null
        ? [
            ShowingTooltipIndicators([
              LineBarSpot(barData, 0, spots[selectedIndex]),
            ]),
          ]
        : <ShowingTooltipIndicators>[];

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
            clipData: const FlClipData(
              top: true,
              bottom: true,
              left: false,
              right: false,
            ),
            minX: minX,
            maxX: chartMaxX,
            minY: paddedMin,
            maxY: paddedMax,
            showingTooltipIndicators: tooltipIndicators,
            lineBarsData: [
              barData,
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
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                tooltipMargin: 8,
                getTooltipItems: (touchedSpots) =>
                    touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toStringAsFixed(2)}$valueSuffix',
                        const TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      );
                    }).toList(growable: false),
              ),
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent) return;
                final hits = response?.lineBarSpots;
                if (hits != null && hits.isNotEmpty) {
                  final s = hits.first;
                  final i = s.spotIndex;
                  if (i >= 0 && i < _spotDates.length) {
                    setState(() {
                      if (_selectedSpotIndex == i) {
                        _selectedSpotIndex = null;
                      } else {
                        _selectedSpotIndex = i;
                      }
                    });
                  }
                  return;
                }
                setState(() {
                  _selectedSpotIndex = null;
                });
              },
            ),
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
                  interval: bottomInterval,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 6,
                    fitInside: SideTitleFitInsideData(
                      enabled: true,
                      distanceFromEdge: 4,
                      parentAxisSize: meta.parentAxisSize,
                      axisPosition: meta.axisPosition,
                    ),
                    child: bottomTitle(value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Chart Series ---
  ({
    List<FlSpot> spots,
    List<DateTime> spotDates,
    double minX,
    double maxX,
    double bottomInterval,
    Widget Function(double) bottomTitle,
  })
  _buildChartSeries({
    required DateTime? latestDay,
    required List<({DateTime date, double bmi})> daily,
    required List<BodyMetric> all,
    required double? heightCm,
  }) {
    bool isNearInteger(double v) => (v - v.roundToDouble()).abs() < 0.001;

    Widget titleText(String s) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        s,
        style: const TextStyle(fontSize: 12, color: AppTheme.mutedForeground),
      ),
    );

    if (latestDay == null) {
      return (
        spots: <FlSpot>[],
        spotDates: <DateTime>[],
        minX: 0,
        maxX: 1,
        bottomInterval: 1,
        bottomTitle: (_) => const SizedBox(),
      );
    }

    final latest = _startOfDay(latestDay);

    switch (_range) {
      case _BmiRange.d:
        // D: 00 → 24 with 6-hour ticks. Use all records within latest day.
        final entries = <({DateTime t, double bmi})>[];
        for (final m in all) {
          final bmi = _bmiForMetric(m, heightCm);
          if (bmi == null || bmi <= 0) continue;

          final day = _metricLocalDay(m);
          if (day == null || day != latest) continue;

          final t = _metricLocalTimestamp(m) ?? day;
          entries.add((t: t, bmi: bmi));
        }
        entries.sort((a, b) => a.t.compareTo(b.t));
        if (entries.isEmpty) {
          return (
            spots: <FlSpot>[],
            spotDates: <DateTime>[],
            minX: 0,
            maxX: 24,
            bottomInterval: 6,
            bottomTitle: (v) {
              if (!isNearInteger(v)) return const SizedBox();
              final vv = v.round();
              if (vv % 6 != 0) return const SizedBox();
              return titleText(vv.toString().padLeft(2, '0'));
            },
          );
        }

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (final e in entries) {
          final x = e.t.hour + e.t.minute / 60.0;
          spots.add(FlSpot(x, e.bmi));
          dates.add(e.t);
        }
        return (
          spots: spots,
          spotDates: dates,
          minX: 0,
          maxX: 24,
          bottomInterval: 6,
          bottomTitle: (v) {
            if (!isNearInteger(v)) return const SizedBox();
            final vv = v.round();
            if (vv % 6 != 0) return const SizedBox();
            return titleText(vv.toString().padLeft(2, '0'));
          },
        );

      case _BmiRange.w:
        // W: Sunday → Saturday, aligned to current week start.
        final start = _startOfDay(widget.currentWeekStart);
        final end = start.add(const Duration(days: 6));
        final visible = daily
            .where((p) => !p.date.isBefore(start) && !p.date.isAfter(end))
            .toList();

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (final p in visible) {
          final dx = p.date.difference(start).inDays.toDouble();
          spots.add(FlSpot(dx, p.bmi));
          dates.add(p.date);
        }

        const dow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
        return (
          spots: spots,
          spotDates: dates,
          minX: 0,
          maxX: 6,
          bottomInterval: 1,
          bottomTitle: (v) {
            if (!isNearInteger(v)) return const SizedBox();
            final i = v.round();
            if (i < 0 || i > 6) return const SizedBox();
            return titleText(dow[i]);
          },
        );

      case _BmiRange.m:
        // M: current month (1..end), ticks at 1/8/15/22.
        final monthStart = DateTime(latest.year, latest.month, 1);
        final monthEnd = DateTime(latest.year, latest.month + 1, 0);
        final visible = daily
            .where(
              (p) => !p.date.isBefore(monthStart) && !p.date.isAfter(monthEnd),
            )
            .toList();

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (final p in visible) {
          spots.add(FlSpot(p.date.day.toDouble(), p.bmi));
          dates.add(p.date);
        }
        return (
          spots: spots,
          spotDates: dates,
          minX: 1,
          maxX: monthEnd.day.toDouble(),
          bottomInterval: 1,
          bottomTitle: (v) {
            if (!isNearInteger(v)) return const SizedBox();
            final d = v.round();
            if (d != 1 && d != 8 && d != 15 && d != 22) {
              return const SizedBox();
            }
            return titleText(d.toString());
          },
        );

      case _BmiRange.m6:
        // 6M: past five months + current month (monthly points).
        final months = <DateTime>[];
        for (int i = 5; i >= 0; i--) {
          months.add(DateTime(latest.year, latest.month - i, 1));
        }

        final monthlyLastByIndex = <int, ({DateTime date, double bmi})>{};
        for (final p in daily) {
          final monthIndex = months.indexWhere(
            (m) => m.year == p.date.year && m.month == p.date.month,
          );
          if (monthIndex < 0) continue;
          monthlyLastByIndex[monthIndex] = (date: p.date, bmi: p.bmi);
        }

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (int i = 0; i < months.length; i++) {
          final last = monthlyLastByIndex[i];
          if (last == null) continue;
          spots.add(FlSpot(i.toDouble(), last.bmi));
          dates.add(last.date);
        }

        return (
          spots: spots,
          spotDates: dates,
          minX: 0,
          maxX: 5,
          bottomInterval: 1,
          bottomTitle: (v) {
            if (!isNearInteger(v)) return const SizedBox();
            final i = v.round();
            if (i < 0 || i > 5) return const SizedBox();
            final m = months[i];
            return titleText(DateFormat('MMM').format(m));
          },
        );

      case _BmiRange.y:
        // Y: months of this year, first letter only (monthly points).
        final yearStart = DateTime(latest.year, 1, 1);
        final months = List.generate(
          12,
          (i) => DateTime(yearStart.year, i + 1, 1),
        );

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (int i = 0; i < months.length; i++) {
          final ms = months[i];
          final me = DateTime(ms.year, ms.month + 1, 0);
          final inMonth = daily
              .where((p) => !p.date.isBefore(ms) && !p.date.isAfter(me))
              .toList();
          if (inMonth.isEmpty) continue;
          final last = inMonth.last;
          spots.add(FlSpot((i + 1).toDouble(), last.bmi));
          dates.add(last.date);
        }

        return (
          spots: spots,
          spotDates: dates,
          minX: 1,
          maxX: 12,
          bottomInterval: 1,
          bottomTitle: (v) {
            if (!isNearInteger(v)) return const SizedBox();
            final i = v.round();
            if (i < 1 || i > 12) return const SizedBox();
            final m = DateFormat('MMM').format(DateTime(latest.year, i, 1));
            return titleText(m.substring(0, 1));
          },
        );
    }
  }
}
