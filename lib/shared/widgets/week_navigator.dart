import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A pill-shaped week navigator with ‹ [This Week / MMM d – MMM d] › chevrons.
/// Same visual style as DateNavigator.
class WeekNavigator extends StatelessWidget {
  /// The Sunday that starts the displayed week.
  final DateTime weekStart;
  final ValueChanged<DateTime> onWeekChanged;

  const WeekNavigator({
    super.key,
    required this.weekStart,
    required this.onWeekChanged,
  });

  bool get _isCurrentWeek {
    final now = DateTime.now();
    final day = now.weekday % 7; // Sunday = 0
    final thisSunday = DateTime(now.year, now.month, now.day - day);
    return thisSunday == weekStart;
  }

  String get _label {
    if (_isCurrentWeek) return 'This Week';
    final end = weekStart.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chevron(
            Icons.chevron_left,
            () => onWeekChanged(weekStart.subtract(const Duration(days: 7))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          _chevron(
            Icons.chevron_right,
            _isCurrentWeek
                ? null
                : () => onWeekChanged(weekStart.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }

  Widget _chevron(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? Colors.white30 : Colors.white,
        ),
      ),
    );
  }
}
