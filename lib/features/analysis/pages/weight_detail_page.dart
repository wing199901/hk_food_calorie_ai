import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_time_policy.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';
import '../../../shared/providers/providers.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';
import 'calorie_surplus_detail_page.dart';
import 'healthy_range_detail_page.dart';
import 'weight_formula_detail_page.dart';

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
  int? _selectedSpotIndex;

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
                        '${spot.y.toStringAsFixed(1)}$valueSuffix',
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
                        _selectedValue = null;
                        _selectedDate = null;
                      } else {
                        _selectedSpotIndex = i;
                        _selectedValue = s.y;
                        _selectedDate = _spotDates[i];
                      }
                    });
                  }
                  return;
                }
                setState(() {
                  _selectedSpotIndex = null;
                  _selectedValue = null;
                  _selectedDate = null;
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
          title: 'How Your Weight Range Is Calculated',
          subtitle:
              'BMI 18.5 + your height define the healthy range.',
          icon: Icons.monitor_weight_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFD8FAEC), Color(0xFFBBF7D0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HealthyRangeDetailPage(
                  currentWeightKg: wKg,
                  heightCm: hCm,
                  lowerKg: lowerKg,
                  upperKg: devineUpperKg,
                  gender: profile.gender,
                  unitSystem: profile.unitSystem,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _knowledgeNavCard(
          title: 'How We Calculate Your Target Range',
          subtitle:
              'Devine base weight + height adjustment set your target range.',
          icon: Icons.calculate_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFEAD8), Color(0xFFFFD7AE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WeightFormulaDetailPage(
                  heightCm: hCm,
                  lowerKg: lowerKg,
                  upperKg: devineUpperKg,
                  baseKg: baseKg,
                  heightText: heightText,
                  lowerText: lowerText,
                  upperText: upperText,
                  currentWeightKg: wKg,
                  gender: profile.gender,
                  unitSystem: profile.unitSystem,
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
                builder: (_) => const CalorieSurplusDetailPage(),
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
