import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../services/storage_service.dart';
import '../models/body_metric.dart';
import '../theme/app_theme.dart';
import '../widgets/week_navigator.dart';

class AnalysisPage extends StatefulWidget {
  final Function(String)? onNavigate;
  final StorageService storage;

  const AnalysisPage({super.key, this.onNavigate, required this.storage});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  List<Map<String, dynamic>> weeklyData = [];
  List<BodyMetric> bodyData = [];
  Map<String, int> todayStats = {
    'consumed': 0,
    'target': 2000,
    'remaining': 2000,
  };
  late DateTime currentWeekStart;
  int? _selectedBarIndex;
  int? _selectedMacroIndex;
  int? _selectedBodyIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final day = now.weekday % 7; // Sunday = 0
    currentWeekStart = DateTime(now.year, now.month, now.day - day);
    _loadData();
    widget.storage.addListener(_loadData);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_loadData);
    super.dispose();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      weeklyData = widget.storage.getRangeData(currentWeekStart, 7);
      todayStats = widget.storage.getStatsForDate(DateTime.now());
      bodyData = widget.storage.getBodyHistory();
    });
  }

  void _changeWeek(DateTime newWeekStart) {
    setState(() {
      currentWeekStart = newWeekStart;
      _selectedBarIndex = null;
      _selectedMacroIndex = null;
      _selectedBodyIndex = null;
    });
    _loadData();
  }

  int get _weekAverage {
    if (weeklyData.isEmpty) return 0;
    final total = weeklyData.fold<int>(0, (s, d) => s + (d['calories'] as int));
    return total ~/ weeklyData.length;
  }

  int get _daysOnTarget {
    return weeklyData.where((d) {
      final cal = d['calories'] as int;
      final target = d['target'] as int;
      return cal >= target * 0.9 && cal <= target * 1.1;
    }).length;
  }

  int get _streak {
    int streak = 0;
    for (int i = weeklyData.length - 1; i >= 0; i--) {
      if ((weeklyData[i]['calories'] as int) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  void _handleBarTap(int index) {
    if (index < weeklyData.length) {
      setState(() {
        // Toggle selection: tap again to deselect
        _selectedBarIndex = (_selectedBarIndex == index) ? null : index;
      });
    }
  }

  Widget? _buildSelectedDayHourlyChart() {
    if (_selectedBarIndex == null || _selectedBarIndex! >= weeklyData.length) {
      return null;
    }
    final d = weeklyData[_selectedBarIndex!];
    final date = d['fullDate'] as DateTime;

    // Get hourly breakdown
    final meals = widget.storage.getMealsForDate(date);
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
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  HorizontalLine(
                    y: 2000,
                    color: Colors.grey[200]!,
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

  Widget _detailChip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Macro detail panel ──────────────────────────────────────

  void _handleMacroTap(int index) {
    if (index < weeklyData.length) {
      setState(() {
        _selectedMacroIndex = (_selectedMacroIndex == index) ? null : index;
      });
    }
  }

  Widget? _buildSelectedMacroDetail() {
    if (_selectedMacroIndex == null ||
        _selectedMacroIndex! >= weeklyData.length) {
      return null;
    }
    final d = weeklyData[_selectedMacroIndex!];
    final protein = d['protein'] as int;
    final carbs = d['carbs'] as int;
    final fat = d['fat'] as int;
    final total = protein + carbs + fat;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _detailChip('Total', '${total}g', AppTheme.mutedForeground),
          const SizedBox(width: 8),
          _detailChip('Protein', '${protein}g', const Color(0xFF8884D8)),
          const SizedBox(width: 8),
          _detailChip('Carbs', '${carbs}g', const Color(0xFF82CA9D)),
          const SizedBox(width: 8),
          _detailChip('Fat', '${fat}g', const Color(0xFFFFC658)),
        ],
      ),
    );
  }

  // ─── Body Metrics detail panel ───────────────────────────────

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
                : (hasWaist ? '${waistline.toStringAsFixed(1)} cm' : 'No data'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _detailChip(
                'Weight',
                hasWeight ? '${weight.toStringAsFixed(1)} kg' : '—',
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _detailChip(
                'Waist',
                hasWaist ? '${waistline.toStringAsFixed(1)} cm' : '—',
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Title & week nav
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Analysis',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      WeekNavigator(
                        weekStart: currentWeekStart,
                        onWeekChanged: _changeWeek,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    children: [
                      _headerStat(
                        Icons.trending_up,
                        'Avg/Day',
                        '$_weekAverage',
                        'kcal',
                      ),
                      const SizedBox(width: 8),
                      _headerStat(
                        Icons.gps_fixed,
                        'On Target',
                        '$_daysOnTarget/7',
                        'days',
                      ),
                      const SizedBox(width: 8),
                      _headerStat(
                        Icons.emoji_events,
                        'Streak',
                        '$_streak',
                        'days',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Charts
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildEnergyChart(),
                const SizedBox(height: 24),
                _buildMacroChart(),
                const SizedBox(height: 24),
                _buildBodyMetricsChart(),
                const SizedBox(height: 24),
                _buildInsights(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(IconData icon, String label, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Energy Intake Bar Chart ─────────────────────────────────

  Widget _buildEnergyChart() {
    // Summary values
    final totalCal = weeklyData.fold<int>(
      0,
      (s, d) => s + (d['calories'] as int),
    );
    final avgTarget = weeklyData.isNotEmpty
        ? weeklyData.fold<int>(0, (s, d) => s + (d['target'] as int)) ~/
              weeklyData.length
        : 0;

    // Dynamic maxY: round avgTarget up to the nearest 2000 so midY is always a whole-k
    final maxY = (((avgTarget > 0 ? avgTarget : 2000) / 2000).ceil() * 2000)
        .toDouble();
    final midY = maxY / 2; // always a whole-k value (1k, 2k, 3k...)
    final gridInterval = maxY / 4; // 5 lines: 0, 1×, 2×, 3×, 4× = maxY

    String fmtY(double v) {
      if (v == 0) return '0';
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }

    // Date subtitle – show selected day when a bar is tapped
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

    return _chartCard(
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
                color: Colors.grey[200]!,
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
                HorizontalLine(
                  y: maxY,
                  color: Colors.grey[200]!,
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
      summary: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: _summaryChip(
                color: AppTheme.primary,
                label: 'Consumed',
                value: '$totalCal kcal',
              ),
            ),
            Expanded(
              child: _summaryChip(
                color: AppTheme.accent,
                label: 'TEE',
                value: '$avgTarget kcal',
              ),
            ),
          ],
        ),
      ),
      expandedDetail: _buildSelectedDayHourlyChart(),
    );
  }

  // ─── Macro Stacked Area Chart ────────────────────────────────

  Widget _buildMacroChart() {
    final maxMacro = weeklyData.fold<int>(0, (max, d) {
      final total =
          (d['protein'] as int) + (d['carbs'] as int) + (d['fat'] as int);
      return total > max ? total : max;
    });
    final maxY = (maxMacro * 1.3).ceilToDouble();

    // Totals for header
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

    // Date subtitle – show selected day when a point is tapped
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

    return _chartCard(
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
                const Color(0xFF8884D8),
              ),
              _macroLine(
                weeklyData.map((d) => (d['carbs'] as int).toDouble()).toList(),
                const Color(0xFF82CA9D),
              ),
              _macroLine(
                weeklyData.map((d) => (d['fat'] as int).toDouble()).toList(),
                const Color(0xFFFFC658),
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
                color: Colors.grey[200]!,
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
                HorizontalLine(
                  y: maxY > 0 ? maxY : 100,
                  color: Colors.grey[200]!,
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
      summary: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: _summaryChip(
                color: const Color(0xFF8884D8),
                label: 'Protein',
                value: '${totalProtein}g',
              ),
            ),
            Expanded(
              child: _summaryChip(
                color: const Color(0xFF82CA9D),
                label: 'Carbs',
                value: '${totalCarbs}g',
              ),
            ),
            Expanded(
              child: _summaryChip(
                color: const Color(0xFFFFC658),
                label: 'Fat',
                value: '${totalFat}g',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a nice round interval so the Y-axis shows 3-5 labels.
  double _niceInterval(double maxY) {
    if (maxY <= 0) return 1;
    final rough = maxY / 4; // aim for ~4 intervals
    // Round to a "nice" number (1, 2, 5, 10, 20, 50, 100, 200, 500, …)
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

  // ─── Body Metrics Line Chart ─────────────────────────────────

  Widget _buildBodyMetricsChart() {
    // Build chart data for the current week using body history
    final fmt = DateFormat('yyyy-MM-dd');
    final entryMap = <String, Map<String, double>>{};

    // Populate from actual body history data
    for (final m in bodyData) {
      entryMap[m.date] = {
        'weight': m.weight ?? 0,
        'waistline': m.waistline ?? 0,
      };
    }

    // If no body data exists at all, use current profile values for today
    if (entryMap.isEmpty) {
      final profile = widget.storage.getUserProfile();
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

    // Latest weight & waist for header display
    final latestWeight = weightSpots.isNotEmpty
        ? weightSpots.last.y.toStringAsFixed(1)
        : '—';
    final latestWaist = waistSpots.isNotEmpty
        ? waistSpots.last.y.toStringAsFixed(1)
        : '—';
    final hasAnyWeight = weightSpots.isNotEmpty;

    // Date subtitle – show selected day when a point is tapped
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

    return _chartCard(
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
                        color: Colors.blue,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.blue,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                    if (waistSpots.isNotEmpty)
                      LineChartBarData(
                        spots: waistSpots,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.orange,
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
                          const dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
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
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0,
                        color: Colors.grey[200]!,
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
                        _handleBodyTap(response.lineBarSpots!.first.x.toInt());
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
      summary: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: _summaryChip(
                color: Colors.blue,
                label: 'Weight',
                value: '$latestWeight kg',
              ),
            ),
            Expanded(
              child: _summaryChip(
                color: Colors.orange,
                label: 'Waist',
                value: '$latestWaist cm',
              ),
            ),
          ],
        ),
      ),

      expandedDetail: _buildSelectedBodyDetail(chartData),
    );
  }

  // ─── Insights ────────────────────────────────────────────────

  Widget _buildInsights() {
    final target = todayStats['target'] ?? 2000;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: AppTheme.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Insights & Tips',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_weekAverage < target * 0.8 && _weekAverage > 0)
            _insightTile(
              AppTheme.warning,
              'Energy Deficit Alert',
              'Your average intake is significantly below your TEE target. Ensure you\'re fueling your body adequately for your activity level.',
            ),
          if (_weekAverage > target * 1.2)
            _insightTile(
              AppTheme.accent,
              'Calorie Surplus',
              'Your average intake is above your TEE. This might lead to weight gain unless you\'re intentionally bulking.',
            ),
          _insightTile(
            AppTheme.secondary,
            'Understanding TEE',
            'Your Total Energy Expenditure (TEE) is the scientifically calculated amount of energy your body needs daily. Aim to match your intake with this number for maintenance.',
            icon: Icons.info_outline,
          ),
          _insightTile(
            AppTheme.primary,
            'Protein Power',
            'Try to include a source of protein in every meal to support muscle maintenance and satiety.',
          ),
          if (_daysOnTarget >= 5)
            _insightTile(
              Colors.green,
              '🎉 Outstanding consistency!',
              'You\'ve hit your TEE target on $_daysOnTarget days this week!',
            ),
          if (_streak >= 3)
            _insightTile(
              Colors.orange,
              '🔥 You\'re on fire!',
              '$_streak-day streak of consistent tracking!',
            ),
        ],
      ),
    );
  }

  Widget _insightTile(
    Color color,
    String title,
    String body, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2),
                child: Icon(icon, size: 16, color: color),
              )
            else
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 12, top: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 13,
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

  // ─── Shared Chart Card ───────────────────────────────────────

  Widget _chartCard({
    required String title,
    required Widget child,
    Widget? header,
    Widget? summary,
    List<Widget>? legend,

    Widget? expandedDetail,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) header,
              if (header != null) const SizedBox(height: 16),
              child,
              if (expandedDetail != null) ...[
                const SizedBox(height: 8),
                expandedDetail,
              ],
              if (summary != null) summary,
              if (legend != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: legend,
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip({
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
