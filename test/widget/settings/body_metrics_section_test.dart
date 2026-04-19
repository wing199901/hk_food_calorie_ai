import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/settings/widgets/body_metrics_section.dart';

void main() {
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows essential quick-edit inputs and intake range summary', (
    tester,
  ) async {
    useTallViewport(tester);
    var updatePressed = false;

    final weightCtrl = TextEditingController(text: '70');
    final heightCtrl = TextEditingController(text: '175');
    final waistlineCtrl = TextEditingController(text: '80');

    addTearDown(weightCtrl.dispose);
    addTearDown(heightCtrl.dispose);
    addTearDown(waistlineCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BodyMetricsSection(
              weightCtrl: weightCtrl,
              heightCtrl: heightCtrl,
              waistlineCtrl: waistlineCtrl,
              onUpdateToday: () {
                updatePressed = true;
              },
              isMetric: true,
            ),
          ),
        ),
      ),
    );

    final weightPos = tester.getTopLeft(find.text('Weight'));
    final heightPos = tester.getTopLeft(find.text('Height'));
    final waistlinePos = tester.getTopLeft(find.text('Waistline'));

    expect(heightPos.dx, greaterThan(weightPos.dx));
    expect((weightPos.dy - heightPos.dy).abs(), lessThan(2));
    expect(waistlinePos.dy, greaterThan(heightPos.dy));

    final firstRowWeightFieldPos = tester.getTopLeft(
      find.byType(TextField).at(0),
    );
    final firstRowHeightFieldPos = tester.getTopLeft(
      find.byType(TextField).at(1),
    );
    expect(
      (firstRowWeightFieldPos.dy - firstRowHeightFieldPos.dy).abs(),
      lessThan(2),
    );

    expect(find.text('Goal Direction'), findsNothing);
    expect(find.text('Change Amount'), findsNothing);
    expect(find.text('Waistline'), findsOneWidget);
    expect(find.text('Activity Level'), findsNothing);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('cm'), findsNWidgets(2));
    expect(find.textContaining('Daily target'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Update'));
    await tester.pump();

    expect(updatePressed, isTrue);
  });

  testWidgets('uses ft for height and in for waistline in imperial mode', (
    tester,
  ) async {
    useTallViewport(tester);
    final weightCtrl = TextEditingController(text: '99');
    final heightCtrl = TextEditingController(text: '5.9');
    final waistlineCtrl = TextEditingController(text: '32');

    addTearDown(weightCtrl.dispose);
    addTearDown(heightCtrl.dispose);
    addTearDown(waistlineCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BodyMetricsSection(
              weightCtrl: weightCtrl,
              heightCtrl: heightCtrl,
              waistlineCtrl: waistlineCtrl,
              onUpdateToday: () {},
              isMetric: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('lbs'), findsOneWidget);
    expect(find.text('ft'), findsOneWidget);
    expect(find.text('in'), findsOneWidget);
  });
}
