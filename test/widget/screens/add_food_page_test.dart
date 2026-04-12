import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/add_food/add_food_page.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_food_analysis_service.dart';
import '../../helpers/fake_storage_service.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'AddFoodPage analyzes valid photo and waits for save confirmation',
    (tester) async {
      final fakeStorage = FakeStorageService();
      final fakeFoodAnalysis = FakeFoodAnalysisService(
        analysisResult: {
          'name': 'Test Chicken Rice',
          'calories': 600,
          'protein': 30,
          'carbs': 70,
          'fat': 20,
          'sugar': 5,
          'image_url': 'https://example.com/signed.jpg',
          'image_path': 'user-1/20260409/meal.jpg',
        },
      );
      String? destination;

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            storageProvider.overrideWith((ref) => fakeStorage),
            foodAnalysisServiceProvider.overrideWith((ref) => fakeFoodAnalysis),
          ],
          child: AddFoodPage(
            onNavigate: (page) => destination = page,
            showTestControls: true,
          ),
        ),
      );

      expect(find.byKey(const Key('quick_add_grid')), findsOneWidget);

      await tester.tap(find.byKey(const Key('test_analyze_valid_photo')));
      await tester.pumpAndSettle();

      expect(destination, isNull);
      expect(fakeStorage.getMeals(), isEmpty);

      await tester.tap(find.text('Add Meal'));
      await tester.pumpAndSettle();

      expect(destination, 'home');
      expect(fakeStorage.getMeals(), hasLength(1));
      expect(
        fakeStorage.getMeals().first.image,
        'https://example.com/signed.jpg',
      );
      expect(
        fakeStorage.getMeals().first.imagePath,
        'user-1/20260409/meal.jpg',
      );
    },
  );

  testWidgets('AddFoodPage lets user edit analysis before confirming save', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService();
    final fakeFoodAnalysis = FakeFoodAnalysisService();

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

    await tester.tap(find.text('Edit Result'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Edited Chicken Rice');
    await tester.enterText(find.byType(TextField).at(1), '520');
    await tester.enterText(find.byType(TextField).at(2), '28');
    await tester.enterText(find.byType(TextField).at(3), '60');
    await tester.enterText(find.byType(TextField).at(4), '14');
    await tester.enterText(find.byType(TextField).at(5), '4');
    await tester.tap(find.text('Confirm Edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Meal'));
    await tester.pumpAndSettle();

    final meals = fakeStorage.getMeals();
    expect(meals, hasLength(1));
    expect(meals.first.name, 'Edited Chicken Rice');
    expect(meals.first.calories, 520);
  });

  testWidgets('AddFoodPage quick add item can open result view', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService();

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: AddFoodPage(onNavigate: (_) {}, showTestControls: true),
      ),
    );

    await tester.tap(find.text('White Rice').first);
    await tester.pumpAndSettle();

    expect(find.text('Add Meal'), findsOneWidget);
  });

  testWidgets('AddFoodPage shows invalid photo error', (tester) async {
    final fakeStorage = FakeStorageService();
    final fakeFoodAnalysis = FakeFoodAnalysisService();

    await tester.pumpWidget(
      buildTestApp(
        overrides: [
          storageProvider.overrideWith((ref) => fakeStorage),
          foodAnalysisServiceProvider.overrideWith((ref) => fakeFoodAnalysis),
        ],
        child: AddFoodPage(onNavigate: (_) {}, showTestControls: true),
      ),
    );

    await tester.tap(find.byKey(const Key('test_analyze_invalid_photo')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Invalid photo format'), findsOneWidget);
  });

  testWidgets('AddFoodPage shows network error on failed analysis', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService();
    final fakeFoodAnalysis = FakeFoodAnalysisService(
      shouldThrowNetworkError: true,
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

    expect(find.textContaining('Network error'), findsOneWidget);
  });
}
