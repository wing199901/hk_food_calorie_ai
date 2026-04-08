import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/widgets/unit_system_selector.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('UnitSystemSelector triggers onChanged when option is tapped', (
    tester,
  ) async {
    var selected = 'metric';

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: UnitSystemSelector(
            value: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();

    expect(selected, 'imperial');
  });
}
