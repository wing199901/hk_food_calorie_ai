import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/widgets/gender_selector.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('GenderSelector triggers onChanged when option is tapped', (
    tester,
  ) async {
    var selected = 'male';

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: GenderSelector(
            value: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    expect(selected, 'female');
  });
}
