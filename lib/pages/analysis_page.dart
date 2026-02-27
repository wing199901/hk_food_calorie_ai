import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/body_metric.dart';
import '../theme/app_theme.dart';

class AnalysisPage extends StatefulWidget {
  final Function(String)? onNavigate;
  final ValueChanged<DateTime>? setDate;
  final StorageService storage;

  const AnalysisPage({
    super.key,
    this.onNavigate,
    this.setDate,
    required this.storage,
  });

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

  void _goToPrevWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    });
    _loadData();
  }

  void _goToNextWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    });
    _loadData();
  }

  bool get _isCurrentWeek {
    final now = DateTime.now();
    final day = now.weekday % 7;
    final thisSunday = DateTime(now.year, now.month, now.day - day);
    return thisSunday == currentWeekStart;
  }

  String get _dateRangeLabel {
    if (_isCurrentWeek) return 'This Week';
    final end = currentWeekStart.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(currentWeekStart)} - ${DateFormat('MMM d').format(end)}';
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
    if (index < weeklyData.length &&
        widget.onNavigate != null &&
        widget.setDate != null) {
      widget.setDate!(weeklyData[index]['fullDate'] as DateTime);
      widget.onNavigate!('log');
    }
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
                      _buildWeekNavigator(),
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

  Widget _buildWeekNavigator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _goToPrevWeek,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.chevron_left, size: 20, color: Colors.white),
            ),
          ),
          Text(
            _dateRangeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: _isCurrentWeek ? null : _goToNextWeek,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: _isCurrentWeek ? Colors.white30 : Colors.white,
              ),
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
    final maxCalories = weeklyData.fold<int>(0, (max, d) {
      final cal = d['calories'] as int;
      final target = d['target'] as int;
      final m = cal > target ? cal : target;
      return m > max ? m : max;
    });
    final maxY = (maxCalories * 1.2).ceilToDouble();

    return _chartCard(
      title: 'Energy Intake',
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: List.generate(weeklyData.length, (i) {
              final d = weeklyData[i];
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (d['calories'] as int).toDouble(),
                    color: AppTheme.primary,
                    width: 10,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  BarChartRodData(
                    toY: (d['target'] as int).toDouble(),
                    color: AppTheme.accent,
                    width: 10,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
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
                    if (i < 0 || i >= weeklyData.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        weeklyData[i]['dateStr'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
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
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent && response?.spot != null) {
                  _handleBarTap(response!.spot!.touchedBarGroupIndex);
                }
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toInt()} kcal',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      legend: [
        _legendItem(AppTheme.primary, 'Consumed'),
        _legendItem(AppTheme.accent, 'TEE Target'),
      ],
      footer: 'Tap columns to view daily log',
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

    return _chartCard(
      title: 'Macronutrient Trends (P/C/F)',
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
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= weeklyData.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        weeklyData[i]['dateStr'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
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
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final labels = ['Protein', 'Carbs', 'Fat'];
                  return LineTooltipItem(
                    '${labels[s.barIndex]}: ${s.y.toInt()}g',
                    TextStyle(color: s.bar.color, fontSize: 12),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      legend: [
        _legendItem(const Color(0xFF8884D8), 'Protein'),
        _legendItem(const Color(0xFF82CA9D), 'Carbs'),
        _legendItem(const Color(0xFFFFC658), 'Fat'),
      ],
      footer: 'Tap chart to view daily log',
    );
  }

  LineChartBarData _macroLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
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
    // Build chart data for the current week using body history + demo data
    final fmt = DateFormat('yyyy-MM-dd');
    final demoBase = <String, Map<String, double>>{};
    final now = DateTime.now();
    for (final days in [30, 20, 10, 5, 1]) {
      final d = now.subtract(Duration(days: days));
      demoBase[fmt.format(d)] = {
        'weight': [
          72.5,
          71.8,
          71.2,
          70.8,
          70.5,
        ][[30, 20, 10, 5, 1].indexOf(days)],
        'waistline': [
          85.0,
          84.0,
          83.0,
          82.5,
          82.0,
        ][[30, 20, 10, 5, 1].indexOf(days)],
      };
    }
    for (final m in bodyData) {
      demoBase[m.date] = {
        'weight': m.weight ?? 0,
        'waistline': m.waistline ?? 0,
      };
    }

    final chartData = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final d = currentWeekStart.add(Duration(days: i));
      final key = fmt.format(d);
      final data = demoBase[key];
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

    return _chartCard(
      title: 'Body Metrics History',
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
                  lineBarsData: [
                    if (weightSpots.isNotEmpty)
                      LineChartBarData(
                        spots: weightSpots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
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
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
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
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= chartData.length)
                            return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              chartData[i]['dateStr'] as String,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
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
                ),
              ),
      ),
      legend: [
        _legendItem(Colors.blue, 'Weight (kg)'),
        _legendItem(Colors.orange, 'Waist (cm)'),
      ],
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
    List<Widget>? legend,
    String? footer,
  }) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          child,
          if (legend != null) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: legend),
          ],
          if (footer != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                footer,
                style: const TextStyle(
                  color: AppTheme.mutedForeground,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
