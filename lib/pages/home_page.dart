import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../services/storage_service.dart';
import '../models/meal.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  final Function(String) onNavigate;
  final DateTime date;
  final ValueChanged<DateTime> setDate;
  final StorageService storage;

  const HomePage({
    super.key,
    required this.onNavigate,
    required this.date,
    required this.setDate,
    required this.storage,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, int> stats = {'consumed': 0, 'target': 2000, 'remaining': 2000};
  List<Meal> meals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.storage.addListener(_loadData);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) _loadData();
  }

  @override
  void dispose() {
    widget.storage.removeListener(_loadData);
    super.dispose();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      stats = widget.storage.getStatsForDate(widget.date);
      meals = widget.storage.getMealsForDate(widget.date);
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
  }

  void _goToPreviousDay() {
    widget.setDate(widget.date.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    if (!_isToday) {
      widget.setDate(widget.date.add(const Duration(days: 1)));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) widget.setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
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
                      // Date navigator
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _iconButton(Icons.chevron_left, _goToPreviousDay),
                            GestureDetector(
                              onTap: _pickDate,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isToday
                                          ? 'Today'
                                          : DateFormat(
                                              'MMM d',
                                            ).format(widget.date),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _iconButton(
                              Icons.chevron_right,
                              _isToday ? null : _goToNextDay,
                            ),
                          ],
                        ),
                      ),
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
                  const SizedBox(height: 20),
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
            padding: const EdgeInsets.all(24),
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
                        borderRadius: BorderRadius.circular(30),
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isToday
                      ? "Today's Meals"
                      : 'Meals on ${DateFormat('MMM d').format(widget.date)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
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
                        const SizedBox(height: 12),
                        const Text(
                          'No meals logged',
                          style: TextStyle(color: AppTheme.mutedForeground),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isToday
                              ? 'Start tracking your food!'
                              : 'No meals recorded for this date',
                          style: const TextStyle(
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
                                    placeholder: (_, __) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.grey[200],
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.grey[200],
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

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white30 : Colors.white,
          size: 20,
        ),
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
              const SizedBox(width: 6),
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
