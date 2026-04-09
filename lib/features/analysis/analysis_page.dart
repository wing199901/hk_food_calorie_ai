import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import 'widgets/analysis_preview_card.dart';
import 'widgets/weight_preview.dart';
import 'widgets/height_preview.dart';
import 'widgets/bmi_preview.dart';
import 'widgets/energy_preview.dart';
import 'widgets/macro_preview.dart';
import 'pages/energy_intake_detail_page.dart';
import 'pages/weight_detail_page.dart';
import 'pages/height_detail_page.dart';
import 'pages/bmi_detail_page.dart';
import 'pages/macronutrient_detail_page.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  final Function(String)? onNavigate;

  const AnalysisPage({super.key, this.onNavigate});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  late DateTime currentWeekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final day = now.weekday % 7; // Sunday = 0
    currentWeekStart = DateTime(now.year, now.month, now.day - day);
  }

  int _weekAverage(List<Map<String, dynamic>> weeklyData) {
    if (weeklyData.isEmpty) return 0;
    final total = weeklyData.fold<int>(0, (sum, day) {
      return sum + (day['calories'] as int);
    });
    return total ~/ weeklyData.length;
  }

  int _daysOnTarget(List<Map<String, dynamic>> weeklyData) {
    return weeklyData.where((day) {
      final calories = day['calories'] as int;
      final target = day['target'] as int;
      return calories >= target * 0.9 && calories <= target * 1.1;
    }).length;
  }

  int _streak(List<Map<String, dynamic>> weeklyData) {
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

  DateTime? _lastDayWithData(
    List<Map<String, dynamic>> data,
    bool Function(Map<String, dynamic>) hasData,
  ) {
    for (int i = data.length - 1; i >= 0; i--) {
      final day = data[i];
      if (hasData(day)) {
        return day['lastUpdate'] as DateTime? ?? day['fullDate'] as DateTime;
      }
    }
    return null;
  }

  DateTime? _parseIsoDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _formatLastUpdate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final target = date.toLocal();
    final today = DateUtils.dateOnly(now);
    final targetDay = DateUtils.dateOnly(target);

    // Not today: show date like "22 Mar".
    if (targetDay != today) {
      return DateFormat('dd MMM').format(target);
    }

    // Today with no meaningful time info (date-only values) should stay "Today".
    final hasTime =
        target.hour != 0 ||
        target.minute != 0 ||
        target.second != 0 ||
        target.millisecond != 0 ||
        target.microsecond != 0;
    if (!hasTime) return 'Today';

    // If the update is near current time, show the exact time like "00:00".
    const nearWindow = Duration(hours: 6);
    final diff = now.difference(target).abs();
    if (diff <= nearWindow) {
      return DateFormat('HH:mm').format(target);
    }

    // Earlier today updates should show "Today".
    return 'Today';
  }

  @override
  Widget build(BuildContext context) {
    // --- Data Fetching & State ---
    final storage = ref.watch(storageProvider);
    final weeklyData = storage.getRangeData(currentWeekStart, 7);
    final bodyData = storage.getBodyHistory();
    final todayStats = storage.getStatsForDate(DateTime.now());

    // --- Computations ---
    final weekAverage = _weekAverage(weeklyData);
    final daysOnTarget = _daysOnTarget(weeklyData);
    final streak = _streak(weeklyData);

    // --- Last Update Times ---
    final energyUpdated = _lastDayWithData(
      weeklyData,
      (d) => (d['calories'] as int) > 0,
    );
    final bodyUpdated = bodyData.isNotEmpty
        ? (bodyData.last.createdAt != null
              ? DateTime.tryParse(bodyData.last.createdAt!) ??
                    _parseIsoDate(bodyData.last.date)
              : _parseIsoDate(bodyData.last.date))
        : null;
    final macroUpdated = _lastDayWithData(weeklyData, (d) {
      final p = d['protein'] as int;
      final c = d['carbs'] as int;
      final f = d['fat'] as int;
      return p + c + f > 0;
    });

    final profile = storage.getUserProfile();

    // --- UI Layout ---
    return Column(
      children: [
        // --- Header Section ---
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SafeArea(
            bottom: false,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Analysis',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        // --- Scrollable Body Section ---
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Section Title ---
                  const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // --- 1. Energy Intake Preview Card ---
                  AnalysisPreviewCard(
                    title: 'Energy Intake',
                    icon: Icons.insights_rounded,
                    color: AppTheme.chartWeight,
                    lastUpdate: _formatLastUpdate(energyUpdated),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EnergyIntakeDetailPage(
                            weeklyData: weeklyData,
                            currentWeekStart: currentWeekStart,
                            weekAverage: weekAverage,
                            daysOnTarget: daysOnTarget,
                            streak: streak,
                            todayStats: todayStats,
                          ),
                        ),
                      );
                    },
                    child: EnergyPreview(
                      weeklyData: weeklyData,
                      weekAverage: weekAverage,
                      daysOnTarget: daysOnTarget,
                      todayStats: todayStats,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // --- 2. Weight Preview Card ---
                  AnalysisPreviewCard(
                    title: 'Weight',
                    icon: Icons.monitor_weight_outlined,
                    color: AppTheme.secondary,
                    lastUpdate: _formatLastUpdate(bodyUpdated),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WeightDetailPage(
                            bodyData: bodyData,
                            currentWeekStart: currentWeekStart,
                            profileWeight: profile.weight,
                          ),
                        ),
                      );
                    },
                    child: WeightPreview(
                      bodyData: bodyData,
                      currentWeekStart: currentWeekStart,
                      profileWeight: profile.weight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // --- 3. Height Preview Card ---
                  AnalysisPreviewCard(
                    title: 'Height',
                    icon: Icons.height_outlined,
                    color: AppTheme.secondary,
                    lastUpdate: _formatLastUpdate(
                      bodyUpdated,
                    ), // Fixed exact last update instead of Always
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HeightDetailPage(),
                        ),
                      );
                    },
                    child: HeightPreview(
                      bodyData: bodyData,
                      currentWeekStart: currentWeekStart,
                      profileHeight: profile.height,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // --- 4. BMI Preview Card ---
                  AnalysisPreviewCard(
                    title: 'Body Mass Index',
                    icon: Icons.accessibility_new_rounded,
                    color: AppTheme.secondary,
                    lastUpdate: _formatLastUpdate(bodyUpdated),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BmiDetailPage(
                            bodyData: bodyData,
                            currentWeekStart: currentWeekStart,
                          ),
                        ),
                      );
                    },
                    child: BmiPreview(
                      bodyData: bodyData,
                      currentWeekStart: currentWeekStart,
                      profileHeight: profile.height,
                      profileWeight: profile.weight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // --- 5. Macronutrients Preview Card ---
                  AnalysisPreviewCard(
                    title: 'Macronutrients',
                    icon: Icons.local_fire_department_rounded,
                    color: AppTheme.accent,
                    lastUpdate: _formatLastUpdate(macroUpdated),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacronutrientDetailPage(
                            weeklyData: weeklyData,
                            currentWeekStart: currentWeekStart,
                          ),
                        ),
                      );
                    },
                    child: MacroPreview(weeklyData: weeklyData),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
