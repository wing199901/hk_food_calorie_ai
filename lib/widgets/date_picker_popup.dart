import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A [PopupMenuEntry] that renders a [CalendarDatePicker] inline.
class DatePickerPopupEntry extends PopupMenuEntry<DateTime> {
  final DateTime initialDate;
  const DatePickerPopupEntry({super.key, required this.initialDate});

  @override
  double get height => 330;

  @override
  bool represents(DateTime? value) => false;

  @override
  State<DatePickerPopupEntry> createState() => _DatePickerPopupEntryState();
}

class _DatePickerPopupEntryState extends State<DatePickerPopupEntry> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: CalendarDatePicker(
          initialDate: widget.initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          onDateChanged: (date) => Navigator.of(context).pop(date),
        ),
      ),
    );
  }
}

/// Shows a calendar popup positioned right below [key]'s widget.
Future<DateTime?> showDatePickerPopup(
  BuildContext context, {
  required GlobalKey key,
  required DateTime initialDate,
}) async {
  final RenderBox box = key.currentContext!.findRenderObject()! as RenderBox;
  final Offset offset = box.localToGlobal(Offset.zero);
  final Size size = box.size;
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final Rect overlayBounds = overlay.paintBounds;

  return showMenu<DateTime>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(offset.dx, offset.dy + size.height + 6, size.width, 0),
      overlayBounds,
    ),
    items: [DatePickerPopupEntry(initialDate: initialDate)],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 8,
    constraints: const BoxConstraints(maxWidth: 310, minWidth: 300),
  );
}
