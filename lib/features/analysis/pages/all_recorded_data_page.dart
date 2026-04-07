import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/providers/providers.dart';

enum DataType { bmi, weight, height, energy, macro }

class AllRecordedDataPage extends ConsumerWidget {
  final DataType dataType;

  const AllRecordedDataPage({super.key, required this.dataType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(children: [_buildDataSection(context, storage)]),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (dataType) {
      case DataType.bmi:
        return 'All Recorded BMI';
      case DataType.weight:
        return 'All Recorded Weight';
      case DataType.height:
        return 'All Recorded Height';
      case DataType.energy:
        return 'All Recorded Energy Intake';
      case DataType.macro:
        return 'All Recorded Macronutrients';
    }
  }

  Widget _buildDataSection(BuildContext context, dynamic storage) {
    if (dataType == DataType.weight ||
        dataType == DataType.height ||
        dataType == DataType.bmi) {
      final List<dynamic> rawData = storage.getBodyHistory();
      final data = List.from(rawData);
      final profile = storage.getUserProfile();

      // Sort body data by date descending
      data.sort((a, b) {
        DateTime dateA = _parseBodyMetricDate(a);
        DateTime dateB = _parseBodyMetricDate(b);
        return dateB.compareTo(dateA);
      });

      if (data.isEmpty && dataType != DataType.height) {
        return const Center(child: Text('No data available'));
      }
      
      if (dataType == DataType.height && data.isEmpty) {
         if (profile.height != null) {
           // Create a fake entry for today so at least current height is shown
           return _sectionCard(
             title: 'All-Time History',
             child: Column(
               children: [
                 _historyRowBody(null, isLast: true, overrideHeight: profile.height),
               ],
             ),
           );
         }
         return const Center(child: Text('No data available'));
      }

      return _sectionCard(
        title: 'All-Time History',
        child: Column(
          children: [
            for (int i = 0; i < data.length; i++)
              _historyRowBody(data[i], isLast: i == data.length - 1, overrideHeight: profile.height),
          ],
        ),
      );
    } else {
      // For energy and macro, compute daily totals from all meals
      final meals = storage.getMeals();
      if (meals.isEmpty) {
        return const Center(child: Text('No data available'));
      }

      // Group by date string (yyyy-MM-dd)
      final Map<String, Map<String, dynamic>> dailyMap = {};
      for (final meal in meals) {
        final mealDate = DateTime.fromMillisecondsSinceEpoch(meal.timestamp);
        final dateKey =
            '${mealDate.year}-${mealDate.month.toString().padLeft(2, '0')}-${mealDate.day.toString().padLeft(2, '0')}';

        if (!dailyMap.containsKey(dateKey)) {
          dailyMap[dateKey] = {
            'fullDate': DateTime(mealDate.year, mealDate.month, mealDate.day),
            'calories': 0,
            'target': storage.getDailyTarget(),
            'protein': 0,
            'carbs': 0,
            'fat': 0,
          };
        }
        dailyMap[dateKey]!['calories'] += meal.calories;
        dailyMap[dateKey]!['protein'] += meal.protein;
        dailyMap[dateKey]!['carbs'] += meal.carbs;
        dailyMap[dateKey]!['fat'] += meal.fat;
      }

      final dailyList = dailyMap.values.toList()
        ..sort(
          (a, b) =>
              (b['fullDate'] as DateTime).compareTo(a['fullDate'] as DateTime),
        );

      return _sectionCard(
        title: 'All-Time History',
        child: Column(
          children: [
            for (int i = 0; i < dailyList.length; i++)
              dataType == DataType.energy
                  ? _historyRowEnergy(
                      dailyList[i],
                      isLast: i == dailyList.length - 1,
                    )
                  : _historyRowMacro(
                      dailyList[i],
                      isLast: i == dailyList.length - 1,
                    ),
          ],
        ),
      );
    }
  }

  DateTime _parseBodyMetricDate(dynamic item) {
    if (item == null) return DateTime.now();
    DateTime? d;
    if (item.createdAt != null) d = DateTime.tryParse(item.createdAt!);
    if (d == null && item.date != null) {
      final parts = item.date.split('-');
      if (parts.length == 3) {
        d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    }
    return d ?? DateTime.now();
  }

  Widget _historyRowBody(dynamic item, {required bool isLast, double? overrideHeight}) {
    // Parse date
    DateTime date = _parseBodyMetricDate(item);

    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(date);

    String valueStr = '';

    if (dataType == DataType.weight) {
      valueStr = '${item?.weight ?? '-- '} kg';
    } else if (dataType == DataType.height) {
      valueStr = '${overrideHeight ?? '--'} cm';
    } else if (dataType == DataType.bmi) {
      if (item?.bmi != null) {
        valueStr = item.bmi.toStringAsFixed(1);
      } else if (overrideHeight != null && item?.weight != null && overrideHeight > 0) {
        final heightInM = overrideHeight / 100;
        final bmi = item.weight / (heightInM * heightInM);
        valueStr = bmi.toStringAsFixed(1);
      } else {
        valueStr = 'N/A';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foreground,
                  ),
                ),
              ],
            ),
          ),
          Text(
            valueStr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRowEnergy(Map<String, dynamic> day, {required bool isLast}) {
    final date = day['fullDate'] as DateTime;
    final calories = day['calories'] as int;
    final target = day['target'] as int;
    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(date);
    final ratio = target > 0 ? (calories / target) : 0;
    final status = ratio >= 0.9 && ratio <= 1.1
        ? 'On target'
        : ratio > 1.1
        ? 'High'
        : 'Low';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '$calories kcal / $target kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status == 'On target'
                  ? AppTheme.primary
                  : status == 'High'
                  ? AppTheme.accent
                  : AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRowMacro(Map<String, dynamic> day, {required bool isLast}) {
    final date = day['fullDate'] as DateTime;
    final p = day['protein'] as int;
    final c = day['carbs'] as int;
    final f = day['fat'] as int;
    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Protein: $p g  •  Carbs: $c g  •  Fat: $f g',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ), // Replaced generic withValues
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
