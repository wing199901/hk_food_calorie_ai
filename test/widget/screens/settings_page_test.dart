import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/settings/settings_page.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

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

  testWidgets('shows quick-edit + weight goal section and opens setup flow', (
    tester,
  ) async {
    final storage = FakeStorageService(
      profile: UserProfile(
        birthdate: '1996-02-02',
        gender: 'male',
        unitSystem: 'metric',
        weight: 70,
        height: 175,
        weightGoal: 'lose',
        goalWeightDelta: 5,
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
    expect(find.text('Activity Level'), findsNothing);

    expect(find.text('Weight Goal'), findsOneWidget);
    expect(find.text('Goal Direction'), findsOneWidget);
    expect(find.text('Change Amount'), findsOneWidget);
    expect(find.text('Target weight preview: 65.0 kg'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '72');
    await tester.pump();
    expect(find.text('Target weight preview: 67.0 kg'), findsOneWidget);

    expect(
      find.text(
        'Use this to review your weight-goal setup in guided steps.',
      ),
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
}
