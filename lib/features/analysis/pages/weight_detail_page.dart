import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../main.dart';
import '../../../core/utils/app_time_policy.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../add_food/add_food_page.dart';
import '../../../shared/models/body_metric.dart';
import '../../../shared/providers/providers.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';

enum _WeightRange { d, w, m, m6, y }

class WeightDetailPage extends ConsumerStatefulWidget {
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
  ConsumerState<WeightDetailPage> createState() => _WeightDetailPageState();
}

class _WeightDetailPageState extends ConsumerState<WeightDetailPage> {
  _WeightRange _range = _WeightRange.w;
  double? _selectedValue;
  DateTime? _selectedDate;

  // For tap selection mapping.
  List<DateTime> _spotDates = const [];

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

  @override
  Widget build(BuildContext context) {
    // Rebuild when storage changes (profile updates).
    ref.watch(storageSignalProvider);
    final profile = ref.read(storageProvider).getUserProfile();

    // De-dupe: only keep the latest entry per day.
    final byDay = <DateTime, BodyMetric>{};
    DateTime? latestDay;
    for (final m in widget.bodyData) {
      final w = m.weight;
      if (w == null || w <= 0) continue;

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
            .map((e) => (date: e.key, weight: e.value.weight!))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final chart = _buildChartSeries(
      latestDay: latestDay,
      daily: daily,
      all: widget.bodyData,
    );

    final spots = chart.spots;
    _spotDates = chart.spotDates;

    final latestValueText = spots.isNotEmpty
        ? '${spots.last.y.toStringAsFixed(1)}kg'
        : (widget.profileWeight != null
              ? '${widget.profileWeight!.toStringAsFixed(1)}kg'
              : '--kg');

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
              _rangeToggle(),
              const SizedBox(height: AppSpacing.sm),
              _trendLineCard(
                title: 'Weight Trend',
                spots: spots,
                minX: chart.minX,
                maxX: chart.maxX,
                bottomInterval: chart.bottomInterval,
                bottomTitle: chart.bottomTitle,
                color: AppTheme.chartWeight,
                valueSuffix: 'kg',
                latestValueText: latestValueText,
              ),
              const SizedBox(height: AppSpacing.lg),
              _aboutWeightSection(
                heightCm: profile.height,
                latestWeightKg: spots.isNotEmpty
                    ? spots.last.y
                    : widget.profileWeight,
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
    required List<FlSpot> spots,
    required double minX,
    required double maxX,
    required double bottomInterval,
    required Widget Function(double) bottomTitle,
    required Color color,
    required String valueSuffix,
    required String latestValueText,
  }) {
    if (spots.isEmpty) {
      return ChartCard(
        title: title,
        showTitleBadge: false,
        summary: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: SummaryChip(
            color: color,
            label: 'Current',
            value: latestValueText,
          ),
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
    final chartMaxX = maxX + 0.15;
    final paddedMin = span < 0.5 ? minY - 0.5 : minY - span * 0.2;
    final paddedMax = span < 0.5 ? maxY + 0.5 : maxY + span * 0.2;

    return ChartCard(
      title: title,
      showTitleBadge: false,
      summary: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: SummaryChip(
                color: color,
                label: 'Latest',
                value: '${spots.last.y.toStringAsFixed(1)}$valueSuffix',
              ),
            ),
            if (_selectedValue != null && _selectedDate != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SummaryChip(
                  color: AppTheme.secondary,
                  label: 'Selected',
                  value:
                      '${_selectedValue!.toStringAsFixed(1)}$valueSuffix · ${DateFormat('MMM d').format(_selectedDate!.toLocal())}',
                ),
              ),
            ],
          ],
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
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent,
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 0,
                getTooltipItems: (touchedSpots) =>
                    touchedSpots.map((_) => null).toList(growable: false),
              ),
              touchCallback: (event, response) {
                if (event is FlTapUpEvent &&
                    response?.lineBarSpots != null &&
                    response!.lineBarSpots!.isNotEmpty) {
                  final s = response.lineBarSpots!.first;
                  final i = s.spotIndex;
                  if (i >= 0 && i < _spotDates.length) {
                    setState(() {
                      _selectedValue = s.y;
                      _selectedDate = _spotDates[i];
                    });
                  }
                }
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
    required List<({DateTime date, double weight})> daily,
    required List<BodyMetric> all,
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
      case _WeightRange.d:
        // D: 00 → 24 with 6-hour ticks. Use all records within latest day.
        final entries = <({DateTime t, double w})>[];
        for (final m in all) {
          final w = m.weight;
          if (w == null || w <= 0) continue;

          final day = _metricLocalDay(m);
          if (day == null || day != latest) continue;

          final t = _metricLocalTimestamp(m) ?? day;
          entries.add((t: t, w: w));
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
          spots.add(FlSpot(x, e.w));
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

      case _WeightRange.w:
        // W: Sunday → Saturday, same as original.
        final start = _startOfDay(widget.currentWeekStart);
        final end = start.add(const Duration(days: 6));
        final visible = daily
            .where((p) => !p.date.isBefore(start) && !p.date.isAfter(end))
            .toList();

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (final p in visible) {
          final dx = p.date.difference(start).inDays.toDouble();
          spots.add(FlSpot(dx, p.weight));
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

      case _WeightRange.m:
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
          spots.add(FlSpot(p.date.day.toDouble(), p.weight));
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

      case _WeightRange.m6:
        // 6M: past five months + current month (monthly points).
        final months = <DateTime>[];
        for (int i = 5; i >= 0; i--) {
          months.add(DateTime(latest.year, latest.month - i, 1));
        }

        final monthlyLastByIndex = <int, ({DateTime date, double weight})>{};
        for (final p in daily) {
          final monthIndex = months.indexWhere(
            (m) => m.year == p.date.year && m.month == p.date.month,
          );
          if (monthIndex < 0) continue;
          monthlyLastByIndex[monthIndex] = (date: p.date, weight: p.weight);
        }

        final spots = <FlSpot>[];
        final dates = <DateTime>[];
        for (int i = 0; i < months.length; i++) {
          final last = monthlyLastByIndex[i];
          if (last == null) continue;
          spots.add(FlSpot(i.toDouble(), last.weight));
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

      case _WeightRange.y:
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
          spots.add(FlSpot((i + 1).toDouble(), last.weight));
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

  Widget _rangeToggle() {
    const labels = {
      _WeightRange.d: 'D',
      _WeightRange.w: 'W',
      _WeightRange.m: 'M',
      _WeightRange.m6: '6M',
      _WeightRange.y: 'Y',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: CupertinoSlidingSegmentedControl<_WeightRange>(
        groupValue: _range,
        thumbColor: Colors.white,
        backgroundColor: AppTheme.muted,
        children: {
          for (final r in _WeightRange.values)
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
          });
        },
      ),
    );
  }

  Widget _aboutWeightSection({
    required double? heightCm,
    required double? latestWeightKg,
  }) {
    final profile = ref.read(storageProvider).getUserProfile();
    final hCm = heightCm;
    final wKg = latestWeightKg;

    final hM = (hCm != null && hCm > 0) ? hCm / 100.0 : null;
    final bmi = (hM != null && wKg != null && wKg > 0)
        ? (wKg / (hM * hM))
        : null;

    String bmiLabel(double v) {
      if (v < 18.5) return 'underweight';
      if (v < 25) return 'healthy';
      if (v < 30) return 'overweight';
      return 'obese';
    }

    final lowerKg = (hM != null) ? 18.5 * hM * hM : null;
    final baseKg = (profile.gender == 'female') ? 45.5 : 50.0;
    final devineUpperKg = (hCm != null)
        ? (baseKg + 2.3 * ((hCm - 152.4) / 2.54))
        : null;

    final bmiValueText = bmi != null ? bmi.toStringAsFixed(1) : '--';
    final statusText = bmi != null ? bmiLabel(bmi) : 'unknown';
    final heightText = hCm != null ? hCm.toStringAsFixed(0) : '--';
    final lowerText = lowerKg != null
        ? '${lowerKg.toStringAsFixed(1)} kg'
        : '-- kg';
    final upperText = devineUpperKg != null
        ? '${devineUpperKg.toStringAsFixed(1)} kg'
        : '-- kg';

    return Column(
      children: [
        _aboutSectionLabel('About Weight'),
        const SizedBox(height: AppSpacing.xs),
        _aboutInfoCard(
          body: _highlightedBody([
            const TextSpan(text: 'Body weight'),
            const TextSpan(
              text:
                  ' is not only about appearance. It reflects your energy reserve, immune resilience, and recovery capacity. ',
            ),
            const TextSpan(text: 'Your current BMI is '),
            TextSpan(text: bmiValueText, style: _highlightStyle()),
            const TextSpan(text: ', which is in the '),
            TextSpan(text: statusText, style: _highlightStyle()),
            const TextSpan(text: ' category.\n\n'),
            const TextSpan(
              text: 'For healthy weight gain, focus on a steady pace of ',
            ),
            TextSpan(text: '0.25 to 0.5 kg', style: _highlightStyle()),
            const TextSpan(
              text:
                  ' per week, prioritize protein quality, and keep your daily intake consistently above expenditure. ',
            ),
            TextSpan(text: '+500 kcal/day', style: _highlightStyle()),
            const TextSpan(
              text:
                  ' is a practical starting point because it usually lands you near the surplus needed for gradual gain.',
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        _knowledgeNavCard(
          title: 'Why Weight Range Matters',
          subtitle:
              'See Underweight / Normal / Overweight zones and where your target numbers sit.',
          icon: Icons.monitor_weight_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFD8FAEC), Color(0xFFBBF7D0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _HealthyRangeDetailPage(
                  currentWeightKg: wKg,
                  heightCm: hCm,
                  lowerKg: lowerKg,
                  upperKg: devineUpperKg,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _knowledgeNavCard(
          title: 'How We Calculate Your Target Range',
          subtitle:
              'Step-by-step math using base weight + height adjustment, with examples.',
          icon: Icons.calculate_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFEAD8), Color(0xFFFFD7AE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _WeightFormulaDetailPage(
                  heightCm: hCm,
                  lowerKg: lowerKg,
                  upperKg: devineUpperKg,
                  baseKg: baseKg,
                  heightText: heightText,
                  lowerText: lowerText,
                  upperText: upperText,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _knowledgeNavCard(
          title: 'Why +500 kcal per Day?',
          subtitle:
              'Understand the 7,700 kcal = 1 kg theory and how to apply it safely.',
          icon: Icons.local_fire_department_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE0D6), Color(0xFFFFC4AE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _CalorieSurplusDetailPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _knowledgeNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 50,
                    color: AppTheme.foreground.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutInfoCard({required Widget body, Widget? footer}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (footer != null) ...[const SizedBox(height: 8), footer],
        ],
      ),
    );
  }

  TextStyle _aboutBodyStyle() {
    return const TextStyle(
      fontSize: 14,
      color: AppTheme.foreground,
      letterSpacing: -0.2,
      height: 1.45,
    );
  }

  TextStyle _highlightStyle() {
    return const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppTheme.primary,
      letterSpacing: -0.2,
      height: 1.45,
    );
  }

  Widget _highlightedBody(List<TextSpan> spans) {
    return RichText(
      text: TextSpan(style: _aboutBodyStyle(), children: spans),
    );
  }

  Widget _aboutSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.foreground,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _HealthyRangeDetailPage extends StatelessWidget {
  final double? currentWeightKg;
  final double? heightCm;
  final double? lowerKg;
  final double? upperKg;

  const _HealthyRangeDetailPage({
    required this.currentWeightKg,
    required this.heightCm,
    required this.lowerKg,
    required this.upperKg,
  });

  @override
  Widget build(BuildContext context) {
    final hText = heightCm != null ? heightCm!.toStringAsFixed(0) : '--';
    final lowText = lowerKg != null
        ? '${lowerKg!.toStringAsFixed(1)} kg'
        : '-- kg';
    final upText = upperKg != null
        ? '${upperKg!.toStringAsFixed(1)} kg'
        : '-- kg';
    final heightMText = heightCm != null
        ? (heightCm! / 100).toStringAsFixed(2)
        : '--';
    final lowerFormula = heightCm != null
        ? 'BMI 18.5 × $heightMText² ≈ $lowText'
        : 'BMI 18.5 × height²';
    final upperFormula = heightCm != null
        ? 'Base weight + 2.3 × (($hText − 152.4) ÷ 2.54) ≈ $upText'
        : 'Base weight + 2.3 × ((height − 152.4) ÷ 2.54)';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text(
          'How Your Weight Range Is Calculated',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailTextCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For height $hText cm, your healthy growth range is $lowText to $upText.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'BMI 18.5 is the lower healthy threshold. Below it, you are still in the underweight range; above it, your body has a better reserve for energy, immunity, and recovery.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.foreground,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(text: 'Lower bound = '),
                        TextSpan(
                          text: lowerFormula,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '\nMeaning: BMI 18.5 is the minimum healthy threshold. Below this point, you are still considered underweight.\n\nUpper bound = ',
                        ),
                        TextSpan(
                          text: upperFormula,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '\nMeaning: this is the Devine IBW target, where body load is usually light and the balance is medically favorable.\n\nSummary: your healthy weight range is 56.7 kg – 70.5 kg.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _detailTextCard(
              child: _WeightZoneScale(
                lowerKg: lowerKg,
                upperKg: upperKg,
                currentWeightKg: currentWeightKg,
                heightCm: heightCm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightZoneScale extends StatelessWidget {
  final double? lowerKg;
  final double? upperKg;
  final double? currentWeightKg;
  final double? heightCm;

  const _WeightZoneScale({
    required this.lowerKg,
    required this.upperKg,
    required this.currentWeightKg,
    required this.heightCm,
  });

  @override
  Widget build(BuildContext context) {
    final lower = lowerKg ?? 56.7;
    final upper = upperKg ?? 70.5;
    final bmi = currentWeightKg != null && heightCm != null && heightCm! > 0
        ? currentWeightKg! / math.pow(heightCm! / 100, 2)
        : null;

    final displayWeightText = currentWeightKg != null
        ? '${currentWeightKg!.toStringAsFixed(1)}kg'
        : '--kg';

    return LayoutBuilder(
      builder: (_, constraints) {
        final scaleMin = math.max(35.0, lower - 16.0);
        final scaleMax = math.max(scaleMin + 34.0, upper + 10.0);

        double positionFor(double value) {
          return ((value - scaleMin) / (scaleMax - scaleMin))
                  .clamp(0.0, 1.0)
                  .toDouble() *
              constraints.maxWidth;
        }

        final lowerX = positionFor(lower);
        final upperX = positionFor(upper);
        final currentX = bmi != null ? positionFor(currentWeightKg!) : null;
        final underLabelX = lowerX / 2;
        final normalLabelX = (lowerX + upperX) / 2;
        final overLabelX = (upperX + constraints.maxWidth) / 2;

        Widget markerLabel({
          required String title,
          required String value,
          required Color color,
          required double left,
          required bool dotted,
        }) {
          final boxLeft = (left - 48).clamp(0.0, constraints.maxWidth - 96.0);
          return Positioned(
            left: boxLeft,
            top: 0,
            width: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                if (dotted)
                  Column(
                    children: List.generate(
                      10,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.foreground,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 4,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        }

        Widget bottomLabel({required String text, required double center}) {
          final left = (center - 52).clamp(0.0, constraints.maxWidth - 104.0);
          return Positioned(
            left: left,
            top: 110,
            width: 104,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.mutedForeground,
                height: 1.2,
              ),
            ),
          );
        }

        return SizedBox(
          height: 144,
          child: Stack(
            children: [
              if (currentX != null)
                markerLabel(
                  title: 'Current weight',
                  value: displayWeightText,
                  color: AppTheme.foreground,
                  left: currentX,
                  dotted: true,
                ),
              markerLabel(
                title: '',
                value: '${lower.toStringAsFixed(1)}kg',
                color: const Color(0xFF2F9D57),
                left: lowerX,
                dotted: false,
              ),
              markerLabel(
                title: '',
                value: '${upper.toStringAsFixed(1)}kg',
                color: const Color(0xFF5C89D6),
                left: upperX,
                dotted: false,
              ),
              Positioned(
                top: 72,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 24,
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: (lowerX * 1000).round().clamp(1, 100000),
                              child: Container(color: const Color(0xFFEFD3D9)),
                            ),
                            Expanded(
                              flex: ((upperX - lowerX) * 1000).round().clamp(
                                1,
                                100000,
                              ),
                              child: Container(color: const Color(0xFFD6EBD9)),
                            ),
                            Expanded(
                              flex: ((constraints.maxWidth - upperX) * 1000)
                                  .round()
                                  .clamp(1, 100000),
                              child: Container(color: const Color(0xFFEADCC6)),
                            ),
                          ],
                        ),
                        Positioned(
                          left: lowerX - 2,
                          top: 0,
                          child: Container(
                            width: 4,
                            height: 24,
                            color: const Color(0xFF2F9D57),
                          ),
                        ),
                        Positioned(
                          left: upperX - 2,
                          top: 0,
                          child: Container(
                            width: 4,
                            height: 24,
                            color: const Color(0xFF5C89D6),
                          ),
                        ),
                        if (currentX != null)
                          Positioned(
                            left: currentX - 2,
                            top: -18,
                            child: Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.foreground,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              bottomLabel(text: 'Underweight', center: underLabelX),
              bottomLabel(text: 'Normal', center: normalLabelX),
              bottomLabel(text: 'Overweight', center: overLabelX),
            ],
          ),
        );
      },
    );
  }
}

class _WeightFormulaDetailPage extends StatelessWidget {
  final double? heightCm;
  final double? lowerKg;
  final double? upperKg;
  final double baseKg;
  final String heightText;
  final String lowerText;
  final String upperText;

  const _WeightFormulaDetailPage({
    required this.heightCm,
    required this.lowerKg,
    required this.upperKg,
    required this.baseKg,
    required this.heightText,
    required this.lowerText,
    required this.upperText,
  });

  @override
  Widget build(BuildContext context) {
    final formulaLower = heightCm != null
        ? '18.5 × (${(heightCm! / 100).toStringAsFixed(2)}^2) = $lowerText'
        : '--';
    final formulaUpper = heightCm != null
        ? '${baseKg.toStringAsFixed(baseKg % 1 == 0 ? 0 : 1)} + 2.3 × (($heightText − 152.4) ÷ 2.54) = $upperText'
        : '--';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text('How We Calculate Your Range'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailTextCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How the numbers are calculated',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. Base weight: 50 kg (male) or 45.5 kg (female).\n'
                    '2. Height adjustment: +2.3 kg per inch above 152.4 cm.\n'
                    '3. Lower healthy boundary is from BMI 18.5.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _detailTextCard(
              child: Column(
                children: [
                  const Text(
                    'Math Formula',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Lower boundary: BMI 18.5 × height(m)^2',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formulaLower,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Upper boundary: Base weight + 2.3 × ((height_cm − 152.4) ÷ 2.54)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formulaUpper,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieSurplusDetailPage extends StatelessWidget {
  const _CalorieSurplusDetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text('Why +500 kcal per Day?'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailTextCard(
              child: const Text(
                'A common theory in nutrition is:\n\n'
                '7,700 kcal surplus ≈ 1 kg body weight gain\n\n'
                'If your target is about 0.5 kg/week, the weekly surplus is roughly:\n'
                '0.5 × 7,700 = 3,850 kcal/week\n\n'
                'Daily surplus:\n'
                '3,850 ÷ 7 ≈ 550 kcal/day\n\n'
                'So +500 kcal/day is used as a practical and sustainable starting point. '
                'You can then adjust by weekly trend and appetite tolerance.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.foreground,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddFoodPage(onNavigate: (_) {}),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Go to Add Food to log intake',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                MainScaffold.jumpToTab(0);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Home energy overview'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _detailTextCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}
