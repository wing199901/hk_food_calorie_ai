import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/add_food/widgets/result_view.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('ResultView shows analyzing state', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const Scaffold(
          body: ResultView(
            isAnalyzing: true,
            result: null,
            onSave: _noop,
            onCancel: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Analyzing Meal...'), findsOneWidget);
  });

  testWidgets('ResultView shows result and triggers save/cancel callbacks', (
    tester,
  ) async {
    var saved = 0;
    var cancelled = 0;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: ResultView(
            isAnalyzing: false,
            result: const {
              'name': 'Chicken Rice',
              'calories': 600,
              'protein': 30,
              'carbs': 70,
              'fat': 20,
            },
            onSave: () => saved += 1,
            onCancel: () => cancelled += 1,
          ),
        ),
      ),
    );

    expect(find.text('Chicken Rice'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Meal'));
    await tester.pumpAndSettle();

    expect(cancelled, 1);
    expect(saved, 1);
  });
}

void _noop() {}
