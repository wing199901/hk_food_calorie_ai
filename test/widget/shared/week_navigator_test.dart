import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/widgets/week_navigator.dart';

import '../../helpers/test_app.dart';

DateTime _currentWeekSunday() {
  final now = DateTime.now();
  final day = now.weekday % 7;
  return DateTime(now.year, now.month, now.day - day);
}

void main() {
  testWidgets('WeekNavigator shows This Week for current week', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: WeekNavigator(
            weekStart: _currentWeekSunday(),
            onWeekChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('This Week'), findsOneWidget);
  });

  testWidgets('WeekNavigator left chevron navigates to previous week', (
    tester,
  ) async {
    DateTime? changedWeek;
    final start = DateTime(2026, 4, 5);

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: WeekNavigator(
            weekStart: start,
            onWeekChanged: (week) => changedWeek = week,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(changedWeek, DateTime(2026, 3, 29));
  });
}
