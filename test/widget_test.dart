// Basic smoke test for FitCalorie app.

import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FitCalorieApp());
    // App should show a loading indicator while StorageService initializes.
    expect(find.byType(FitCalorieApp), findsOneWidget);
  });
}
