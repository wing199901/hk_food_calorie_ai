import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/body_metric.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/week_navigator.dart';
import 'widgets/health_scores_card.dart';
import 'widgets/energy_chart_card.dart';
import 'widgets/macro_chart_card.dart';
import 'widgets/body_metrics_chart_card.dart';
import 'widgets/insights_section.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  final Function(String)? onNavigate;

  const AnalysisPage({super.key, this.onNavigate});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
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
  }

  void _loadData() {
    if (!mounted) return;
    final storage = ref.read(storageProvider);
    setState(() {
      weeklyData = storage.getRangeData(currentWeekStart, 7);
      todayStats = storage.getStatsForDate(DateTime.now());
      bodyData = storage.getBodyHistory();
    });
  }

  void _changeWeek(DateTime newWeekStart) {
    setState(() {
      currentWeekStart = newWeekStart;
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

  @override
  Widget build(BuildContext context) {
    // Rebuild when storage notifies.
    ref.watch(storageProvider);
    return Column(
      children: [
        // Sticky Header
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
        // Scrollable charts
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const HealthScoresCard(),
                  const SizedBox(height: 24),
                  EnergyChartCard(
                    weeklyData: weeklyData,
                    currentWeekStart: currentWeekStart,
                  ),
                  const SizedBox(height: 24),
                  MacroChartCard(
                    weeklyData: weeklyData,
                    currentWeekStart: currentWeekStart,
                  ),
                  const SizedBox(height: 24),
                  BodyMetricsChartCard(
                    bodyData: bodyData,
                    currentWeekStart: currentWeekStart,
                  ),
                  const SizedBox(height: 24),
                  InsightsSection(
                    weekAverage: _weekAverage,
                    daysOnTarget: _daysOnTarget,
                    streak: _streak,
                    todayStats: todayStats,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
}
