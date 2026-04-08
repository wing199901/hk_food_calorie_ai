import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/widgets/date_navigator.dart';

import '../../helpers/test_app.dart';

class _DateNavigatorHost extends StatefulWidget {
  const _DateNavigatorHost({
    required this.initialDate,
    required this.onChanged,
  });

  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DateNavigatorHost> createState() => _DateNavigatorHostState();
}

class _DateNavigatorHostState extends State<_DateNavigatorHost> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return DateNavigator(
      date: _date,
      onDateChanged: (date) {
        setState(() => _date = date);
        widget.onChanged(date);
      },
    );
  }
}

void main() {
  testWidgets('DateNavigator previous button moves date backward by one day', (
    tester,
  ) async {
    DateTime? selected;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: _DateNavigatorHost(
            initialDate: DateTime(2026, 4, 8),
            onChanged: (date) => selected = date,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(selected, DateTime(2026, 4, 7));
  });

  testWidgets('DateNavigator next button is disabled for today', (
    tester,
  ) async {
    var callbackCount = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: _DateNavigatorHost(
            initialDate: today,
            onChanged: (_) => callbackCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(callbackCount, 0);
  });
}
