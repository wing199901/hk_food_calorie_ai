import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../shared/providers/providers.dart';
import 'data_item_detail_page.dart';

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
        title: const Text(
          'All Recorded Data',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
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

  bool _isMetric(String? unitSystem) => (unitSystem ?? 'metric') == 'metric';

  String _sectionUnitTitle(bool isMetric) {
    switch (dataType) {
      case DataType.bmi:
        return 'BMI';
      case DataType.weight:
        return isMetric ? 'kg' : 'lbs';
      case DataType.height:
        return isMetric ? 'cm' : 'ft';
      case DataType.energy:
        return 'kcal';
      case DataType.macro:
        return 'g';
    }
  }

  Widget _buildDataSection(BuildContext context, dynamic storage) {
    final profile = storage.getUserProfile();
    final isMetric = _isMetric(profile.unitSystem);
    final sectionTitle = _sectionUnitTitle(isMetric);

    if (dataType == DataType.weight ||
        dataType == DataType.height ||
        dataType == DataType.bmi) {
      final List<dynamic> rawData = storage.getBodyHistory();
      final data = List.from(rawData);

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
          return _buildSectionWithUnit(
            unitTitle: sectionTitle,
            child: _sectionCard(
              child: Column(
                children: [
                  _historyRowBody(
                    context,
                    null,
                    isLast: true,
                    overrideHeight: profile.height,
                    isMetric: isMetric,
                  ),
                ],
              ),
            ),
          );
        }
        return const Center(child: Text('No data available'));
      }

      return _buildSectionWithUnit(
        unitTitle: sectionTitle,
        child: _sectionCard(
          child: Column(
            children: [
              for (int i = 0; i < data.length; i++)
                _historyRowBody(
                  context,
                  data[i],
                  isLast: i == data.length - 1,
                  overrideHeight: profile.height,
                  isMetric: isMetric,
                ),
            ],
          ),
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
            'latestDateTime': mealDate,
            'calories': 0,
            'target': storage.getDailyTarget(),
            'protein': 0,
            'carbs': 0,
            'fat': 0,
            'meals': <dynamic>[],
          };
        } else {
          final latest = dailyMap[dateKey]!['latestDateTime'] as DateTime;
          if (mealDate.isAfter(latest)) {
            dailyMap[dateKey]!['latestDateTime'] = mealDate;
          }
        }
        (dailyMap[dateKey]!['meals'] as List<dynamic>).add(meal);
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

      return _buildSectionWithUnit(
        unitTitle: sectionTitle,
        child: _sectionCard(
          child: Column(
            children: [
              for (int i = 0; i < dailyList.length; i++)
                dataType == DataType.energy
                    ? _historyRowEnergy(
                        context,
                        dailyList[i],
                        isLast: i == dailyList.length - 1,
                      )
                    : _historyRowMacro(
                        context,
                        dailyList[i],
                        isLast: i == dailyList.length - 1,
                      ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSectionWithUnit({
    required String unitTitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: const Key('all_recorded_unit_title_padding'),
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Text(
            unitTitle,
            key: const Key('all_recorded_unit_title'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        child,
      ],
    );
  }

  String _formatHistoryDate(DateTime date) {
    final now = DateTime.now();
    final pattern = date.year == now.year
        ? "dd MMM 'at' HH:mm"
        : "dd MMM yyyy 'at' HH:mm";
    return DateFormat(pattern).format(date);
  }

  String _formatDetailDate(DateTime date) {
    final now = DateTime.now();
    final pattern = date.year == now.year
        ? "dd MMM 'at' HH:mm:ss"
        : "dd MMM yyyy 'at' HH:mm:ss";
    return DateFormat(pattern).format(date);
  }

  String _detailValueLabel() {
    switch (dataType) {
      case DataType.bmi:
        return 'BMI';
      case DataType.weight:
        return 'Weight';
      case DataType.height:
        return 'Height';
      case DataType.energy:
        return 'Energy Intake';
      case DataType.macro:
        return 'Macronutrients';
    }
  }

  String _bodyDisplayValue(
    dynamic item, {
    required bool isMetric,
    double? overrideHeight,
    required bool includeUnit,
  }) {
    if (dataType == DataType.weight) {
      final weightKg = (item?.weight as num?)?.toDouble();
      if (weightKg == null) return '--';

      final displayValue = isMetric
          ? weightKg
          : UnitConverter.kgToLbs(weightKg);
      final value = displayValue.toStringAsFixed(1);
      if (!includeUnit) return value;
      return '$value ${isMetric ? 'kg' : 'lbs'}';
    }

    if (dataType == DataType.height) {
      if (overrideHeight == null) return '--';

      final displayValue = isMetric
          ? overrideHeight
          : UnitConverter.cmToFt(overrideHeight);
      final value = displayValue.toStringAsFixed(1);
      if (!includeUnit) return value;
      return '$value ${isMetric ? 'cm' : 'ft'}';
    }

    if (item?.bmi != null) {
      return item.bmi.toStringAsFixed(1);
    }

    if (overrideHeight != null && item?.weight != null && overrideHeight > 0) {
      final heightInM = overrideHeight / 100;
      final bmi = item.weight / (heightInM * heightInM);
      return bmi.toStringAsFixed(1);
    }

    return 'N/A';
  }

  DateTime _parseBodyMetricCreatedAt(dynamic item) {
    if (item?.createdAt != null) {
      final createdAt = DateTime.tryParse(item.createdAt!);
      if (createdAt != null) return createdAt;
    }
    return _parseBodyMetricDate(item);
  }

  bool _isMealUserEntered(dynamic meal) {
    final name = (meal?.name as String? ?? '').toLowerCase();
    final isLikelyAiName =
        name.contains('ai scanned meal') ||
        RegExp(r'\+\s\d+\s+more').hasMatch(name);
    if (isLikelyAiName) return false;

    final image = meal?.image as String?;
    if (image == null || image.isEmpty) return true;
    return !image.startsWith('http');
  }

  bool _isDayUserEntered(Map<String, dynamic> day) {
    final meals = day['meals'] as List<dynamic>?;
    if (meals == null || meals.isEmpty) return true;
    return meals.every(_isMealUserEntered);
  }

  void _openDataDetail(
    BuildContext context, {
    required String value,
    required DateTime date,
    required DateTime dateAdded,
    required bool isUserEntered,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DataItemDetailPage(
          valueLabel: _detailValueLabel(),
          value: value,
          dateText: _formatDetailDate(date),
          dateAddedText: _formatDetailDate(dateAdded),
          isUserEntered: isUserEntered,
        ),
      ),
    );
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

  Widget _historyRowBody(
    BuildContext context,
    dynamic item, {
    required bool isLast,
    double? overrideHeight,
    required bool isMetric,
  }) {
    // Parse date
    final date = _parseBodyMetricDate(item);

    final dateLabel = _formatHistoryDate(date);
    final valueStr = _bodyDisplayValue(
      item,
      isMetric: isMetric,
      overrideHeight: overrideHeight,
      includeUnit: false,
    );
    final detailValue = _bodyDisplayValue(
      item,
      isMetric: isMetric,
      overrideHeight: overrideHeight,
      includeUnit: true,
    );
    final dateAdded = _parseBodyMetricCreatedAt(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDataDetail(
          context,
          value: detailValue,
          date: date,
          dateAdded: dateAdded,
          isUserEntered: true,
        ),
        child: Container(
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
        ),
      ),
    );
  }

  Widget _historyRowEnergy(
    BuildContext context,
    Map<String, dynamic> day, {
    required bool isLast,
  }) {
    final date =
        (day['latestDateTime'] as DateTime?) ?? (day['fullDate'] as DateTime);
    final calories = day['calories'] as int;
    final target = day['target'] as int;
    final dateLabel = _formatHistoryDate(date);
    final ratio = target > 0 ? (calories / target) : 0;
    final status = ratio >= 0.9 && ratio <= 1.1
        ? 'On target'
        : ratio > 1.1
        ? 'High'
        : 'Low';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDataDetail(
          context,
          value: '$calories / $target kcal',
          date: date,
          dateAdded: date,
          isUserEntered: _isDayUserEntered(day),
        ),
        child: Container(
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
                      '$calories / $target',
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
        ),
      ),
    );
  }

  Widget _historyRowMacro(
    BuildContext context,
    Map<String, dynamic> day, {
    required bool isLast,
  }) {
    final date =
        (day['latestDateTime'] as DateTime?) ?? (day['fullDate'] as DateTime);
    final p = day['protein'] as int;
    final c = day['carbs'] as int;
    final f = day['fat'] as int;
    final dateLabel = _formatHistoryDate(date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDataDetail(
          context,
          value: 'Protein: $p g  •  Carbs: $c g  •  Fat: $f g',
          date: date,
          dateAdded: date,
          isUserEntered: _isDayUserEntered(day),
        ),
        child: Container(
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
                      'Protein: $p  •  Carbs: $c  •  Fat: $f',
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
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      key: const Key('all_recorded_list_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        children: [child],
      ),
    );
  }
}
