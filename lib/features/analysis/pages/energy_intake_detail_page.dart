import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../widgets/energy_chart_card.dart';
import '../widgets/ai_insight_section.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';

class EnergyIntakeDetailPage extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final DateTime currentWeekStart;
  final int weekAverage;
  final int daysOnTarget;
  final int streak;
  final Map<String, int> todayStats;

  const EnergyIntakeDetailPage({
    super.key,
    required this.weeklyData,
    required this.currentWeekStart,
    required this.weekAverage,
    required this.daysOnTarget,
    required this.streak,
    required this.todayStats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Energy Intake',
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
              EnergyChartCard(
                weeklyData: weeklyData,
                currentWeekStart: currentWeekStart,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    'About Energy Intake',
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
                      "Your Total Energy Expenditure (TEE) relies on your Basal Metabolic Rate (BMR) and Activity Multiplier. BMR uses FAO/WHO/UNU equations based on age, gender, and body weight. Match your intake to this number for weight maintenance.",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.foreground,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Source: World Health Organization",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AiInsightSection(focus: 'energy'),
              const SizedBox(height: AppSpacing.lg),
              ShowAllDataButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AllRecordedDataPage(dataType: DataType.energy),
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
}
