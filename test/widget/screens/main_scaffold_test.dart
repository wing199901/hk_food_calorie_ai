import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/main.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_food_analysis_service.dart';
import '../../helpers/fake_storage_service.dart';
import '../../helpers/fake_supabase_service.dart';
import '../../helpers/plugin_mocks.dart';
import '../../helpers/test_app.dart';

void main() {
  setUp(() async {
    await mockPackageInfo();
  });

  tearDown(() async {
    await clearPluginMocks();
  });

  testWidgets('MainScaffold navigates tabs and opens AddFood flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeStorage = FakeStorageService();
    final fakeSupabase = FakeSupabaseService();
    final fakeFoodAnalysis = FakeFoodAnalysisService();

    await tester.pumpWidget(
      buildTestApp(
        overrides: [
          storageProvider.overrideWith((ref) => fakeStorage),
          supabaseProvider.overrideWith((ref) => fakeSupabase),
          foodAnalysisServiceProvider.overrideWith((ref) => fakeFoodAnalysis),
        ],
        child: const MainScaffold(showTestControls: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Analysis'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('main_nav_add_button')));
    await tester.pumpAndSettle();
    expect(find.text('Add Food'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test_analyze_valid_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Meal'));
    await tester.pumpAndSettle();

    expect(fakeStorage.getMeals(), hasLength(1));
  });
}
