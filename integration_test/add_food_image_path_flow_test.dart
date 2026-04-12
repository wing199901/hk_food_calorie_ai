import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hk_food_calorie_ai/features/add_food/add_food_page.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../test/helpers/fake_food_analysis_service.dart';
import '../test/helpers/fake_storage_service.dart';
import '../test/helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('persists image path returned by AI analysis', (tester) async {
    final fakeStorage = FakeStorageService();
    final fakeFoodAnalysis = FakeFoodAnalysisService(
      analysisResult: {
        'name': 'Integration Chicken Rice',
        'calories': 610,
        'protein': 31,
        'carbs': 72,
        'fat': 19,
        'sugar': 5,
        'image_url': 'https://example.com/signed.jpg',
        'image_path': 'user-1/20260412/meal.jpg',
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [
          storageProvider.overrideWith((ref) => fakeStorage),
          foodAnalysisServiceProvider.overrideWith((ref) => fakeFoodAnalysis),
        ],
        child: AddFoodPage(onNavigate: (_) {}, showTestControls: true),
      ),
    );

    await tester.tap(find.byKey(const Key('test_analyze_valid_photo')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Meal'));
    await tester.pumpAndSettle();

    final meals = fakeStorage.getMeals();
    expect(meals, hasLength(1));
    expect(meals.first.image, 'https://example.com/signed.jpg');
    expect(meals.first.imagePath, 'user-1/20260412/meal.jpg');
  });
}
