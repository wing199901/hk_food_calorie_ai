import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../widgets/chart_card.dart';
import '../widgets/show_all_data_button.dart';
import 'all_recorded_data_page.dart';

class HeightDetailPage extends ConsumerWidget {
  const HeightDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(storageProvider).getUserProfile();
    final height = profile.height;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Height',
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
              ChartCard(
                title: 'Current Height',
                summary: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: SummaryChip(
                    color: AppTheme.secondary,
                    label: 'Latest',
                    value: height != null
                        ? '${height.toStringAsFixed(1)}cm'
                        : '--cm',
                  ),
                ),
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      height != null
                          ? '${height.toStringAsFixed(1)} cm'
                          : 'No height data configured',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ShowAllDataButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AllRecordedDataPage(dataType: DataType.height),
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
