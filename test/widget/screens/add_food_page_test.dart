import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/add_food/add_food_page.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_food_analysis_service.dart';
import '../../helpers/fake_storage_service.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('AddFoodPage analyzes valid photo and saves meal', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService();
    final fakeFoodAnalysis = FakeFoodAnalysisService();
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

    expect(destination, 'home');
    expect(fakeStorage.getMeals(), hasLength(1));
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
