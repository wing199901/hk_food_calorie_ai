import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/analysis/widgets/abw_formula_simulator.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('ABW simulator toggles source above 120% IBW', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            child: AbwFormulaSimulatorCard(
              heightCm: 175,
              gender: 'male',
              unitSystem: 'metric',
              initialWeightKg: 80,
            ),
          ),
        ),
      ),
    );

    final sourceFinder = find.byKey(const Key('abw_source_value'));
    expect(sourceFinder, findsOneWidget);
    expect(tester.widget<Text>(sourceFinder).data, 'Actual');

    final slider = find.byKey(const Key('abw_weight_slider'));
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(sourceFinder).data, 'ABW');
  });
}
