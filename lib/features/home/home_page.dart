import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/date_navigator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../shared/providers/providers.dart';
import '../../shared/models/meal.dart';
import '../../core/theme/app_theme.dart';

class HomePage extends ConsumerStatefulWidget {
  final Function(String) onNavigate;

  const HomePage({super.key, required this.onNavigate});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Map<String, int> stats = {'consumed': 0, 'target': 2000, 'remaining': 2000};
  List<Meal> meals = [];
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _setDate(DateTime d) {
    setState(() => _date = d);
    _loadData();
  }

  void _loadData() {
    if (!mounted) return;
    final storage = ref.read(storageProvider);
    setState(() {
      stats = storage.getStatsForDate(_date);
      meals = storage.getMealsForDate(_date);
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when storage notifies.
    ref.watch(storageProvider);
    final consumed = stats['consumed'] ?? 0;
    final target = stats['target'] ?? 2000;
    final remaining = stats['remaining'] ?? 2000;
    final percentage = math.min(consumed / target, 1.0);
    final isOverTarget = consumed > target;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // Header with gradient
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
                  // Title & date selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FitCalorie',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Track Your Energy',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      DateNavigator(date: _date, onDateChanged: _setDate),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Circular progress
                  SizedBox(
                    width: 176,
                    height: 176,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 176,
                          height: 176,
                          child: CircularProgressIndicator(
                            value: percentage,
                            strokeWidth: 12,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$consumed',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    ' kcal',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'of $target',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          Icons.gps_fixed,
                          'Remaining',
                          '${isOverTarget ? '+' : ''}${remaining.abs()}',
                          isOverTarget: isOverTarget,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          Icons.local_fire_department,
                          'Meals',
                          '${meals.length}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Add meal button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: GestureDetector(
              onTap: () => widget.onNavigate('camera'),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log New Meal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Take a photo to analyze',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Meal list
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isToday
                      ? "Today's Meals"
                      : 'Meals on ${DateFormat('MMM d').format(_date)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                if (meals.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.muted,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            size: 32,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isToday
                              ? 'Start tracking your food!'
                              : 'No meals recorded for this date',
                          style: const TextStyle(
                            color: AppTheme.mutedForeground,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add a meal to start the day',
                          style: TextStyle(
                            color: AppTheme.mutedForeground,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => widget.onNavigate('log'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              if (meal.image != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: meal.image!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                      width: 64,
                                      height: 64,
                                      color: AppTheme.muted,
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      width: 64,
                                      height: 64,
                                      color: AppTheme.muted,
                                      child: const Icon(Icons.image),
                                    ),
                                  ),
                                ),
                              if (meal.image != null) const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('h:mm a').format(
                                        DateTime.fromMillisecondsSinceEpoch(
                                          meal.timestamp,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: AppTheme.mutedForeground,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${meal.calories}',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    'kcal',
                                    style: TextStyle(
                                      color: AppTheme.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    IconData icon,
    String label,
    String value, {
    bool isOverTarget = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isOverTarget ? AppTheme.destructive : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
