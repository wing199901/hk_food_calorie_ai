import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'date_picker_popup.dart';

/// A pill-shaped date navigator with ‹ [Today / MMM d] › chevrons.
/// Manages its own GlobalKey for the popup and calls [onDateChanged] on pick.
class DateNavigator extends StatefulWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  const DateNavigator({
    super.key,
    required this.date,
    required this.onDateChanged,
  });

  @override
  State<DateNavigator> createState() => _DateNavigatorState();
}

class _DateNavigatorState extends State<DateNavigator> {
  final _labelKey = GlobalKey();

  bool get _isToday {
    final now = DateTime.now();
    return widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
  }

  void _previous() {
    widget.onDateChanged(widget.date.subtract(const Duration(days: 1)));
  }

  void _next() {
    if (!_isToday) {
      widget.onDateChanged(widget.date.add(const Duration(days: 1)));
    }
  }

  Future<void> _pick() async {
    final result = await showDatePickerPopup(
      context,
      key: _labelKey,
      initialDate: widget.date,
    );
    if (result != null) widget.onDateChanged(result);
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
          _chevron(Icons.chevron_left, _previous),
          GestureDetector(
            key: _labelKey,
            onTap: _pick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        : DateFormat('MMM d').format(widget.date),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          _chevron(Icons.chevron_right, _isToday ? null : _next),
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
