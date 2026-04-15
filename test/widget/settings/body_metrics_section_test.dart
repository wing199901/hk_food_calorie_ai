import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/settings/widgets/body_metrics_section.dart';

void main() {
  testWidgets('shows preferred weight field and intake range summary', (
    tester,
  ) async {
    var updatePressed = false;

    final weightCtrl = TextEditingController(text: '70');
    final preferredWeightCtrl = TextEditingController(text: '65');
    final heightCtrl = TextEditingController(text: '175');
    final waistlineCtrl = TextEditingController(text: '80');

    addTearDown(weightCtrl.dispose);
    addTearDown(preferredWeightCtrl.dispose);
    addTearDown(heightCtrl.dispose);
    addTearDown(waistlineCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BodyMetricsSection(
            weightCtrl: weightCtrl,
            preferredWeightCtrl: preferredWeightCtrl,
            heightCtrl: heightCtrl,
            waistlineCtrl: waistlineCtrl,
            activityLevel: 'moderate',
            intakeMin: 1800,
            intakeMax: 2200,
            onActivityChanged: (_) {},
            onUpdateToday: () {
              updatePressed = true;
            },
            isMetric: true,
          ),
        ),
      ),
    );

    expect(find.text('Preferred Weight (kg)'), findsOneWidget);
    expect(find.text('Daily target range: 1800-2200 kcal'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Update'));
    await tester.pump();

    expect(updatePressed, isTrue);
  });
}
