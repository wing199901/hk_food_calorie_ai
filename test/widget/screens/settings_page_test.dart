import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';
import 'package:hk_food_calorie_ai/features/settings/settings_page.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_storage_service.dart';
import '../../helpers/fake_supabase_service.dart';
import '../../helpers/plugin_mocks.dart';
import '../../helpers/test_app.dart';

Text _goalSummaryText(WidgetTester tester, String goalSummaryValue) {
  return tester.widget<Text>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.key == const ValueKey('weight_goal_text') &&
          widget.data == goalSummaryValue,
    ),
  );
}

void main() {
  setUp(() async {
    await mockPackageInfo();
  });

  tearDown(() async {
    await clearPluginMocks();
  });

  testWidgets('shows quick-edit + weight goal section and opens setup flow', (
    tester,
  ) async {
    final storage = FakeStorageService(
      profile: UserProfile(
        birthdate: '1996-02-02',
        gender: 'male',
        unitSystem: 'metric',
        weight: 70,
        targetWeight: 65,
        height: 175,
        waistline: 80,
        activityLevel: 'light',
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [
          storageProvider.overrideWith((ref) => storage),
          supabaseProvider.overrideWith((ref) => FakeSupabaseService()),
        ],
        child: const Scaffold(body: SettingsPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Waistline'), findsOneWidget);
    expect(find.text('Target Weight'), findsOneWidget);
    expect(find.text('Change Amount'), findsNothing);
    expect(find.text('Healthy range: 56.7 kg ~ 70.5 kg'), findsOneWidget);

    final initialGoal = _goalSummaryText(tester, '-5.0 kg, 21.2 BMI');
    expect(initialGoal.style?.color, AppTheme.accent);

    await tester.enterText(find.byType(TextField).at(0), '72');
    await tester.pump();

    final lossGoal = _goalSummaryText(tester, '-7.0 kg, 21.2 BMI');
    expect(lossGoal.style?.color, AppTheme.accent);

    await tester.enterText(find.byType(TextField).at(3), '75');
    await tester.pump();

    final gainGoal = _goalSummaryText(tester, '+3.0 kg, 24.5 BMI');
    expect(gainGoal.style?.color, AppTheme.primary);

    expect(
      find.text('Use this to review your target-weight setup in guided steps.'),
      findsOneWidget,
    );

    final runSetupButton = find.widgetWithText(
      OutlinedButton,
      'Run Setup Again',
    );
    expect(runSetupButton, findsOneWidget);

    final aboutTitle = find.text('About FitCalorie');
    await tester.ensureVisible(aboutTitle);
    await tester.ensureVisible(runSetupButton);
    await tester.pumpAndSettle();
    final aboutY = tester.getTopLeft(aboutTitle).dy;
    final runSetupY = tester.getTopLeft(runSetupButton).dy;
    expect(runSetupY, greaterThan(aboutY));

    await tester.tap(runSetupButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Complete Your Profile'), findsOneWidget);
  });

  testWidgets('shows goal skeleton when target weight is empty', (
    tester,
  ) async {
    final storage = FakeStorageService(
      profile: UserProfile(
        birthdate: '1996-02-02',
        gender: 'male',
        unitSystem: 'metric',
        weight: 70,
        targetWeight: null,
        height: 175,
        waistline: 80,
        activityLevel: 'light',
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [
          storageProvider.overrideWith((ref) => storage),
          supabaseProvider.overrideWith((ref) => FakeSupabaseService()),
        ],
        child: const Scaffold(body: SettingsPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Weight Goal'), findsOneWidget);
    expect(find.text('Goal: '), findsOneWidget);
    expect(find.byKey(const Key('weight_goal_empty')), findsOneWidget);
    expect(find.byKey(const Key('weight_goal_skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('weight_goal_text')), findsNothing);
  });
}
