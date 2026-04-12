import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';
import 'package:hk_food_calorie_ai/features/auth/auth_page.dart';
import 'package:hk_food_calorie_ai/features/check_in/check_in_page.dart';
import 'package:hk_food_calorie_ai/features/onboarding/complete_profile_page.dart';
import 'package:hk_food_calorie_ai/main.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_food_analysis_service.dart';
import '../test/helpers/fake_storage_service.dart';
import '../test/helpers/fake_supabase_service.dart';
import '../test/helpers/plugin_mocks.dart';

enum _FlowStep { login, completeProfile, checkIn, main }

class _FlowHost extends StatefulWidget {
  const _FlowHost();

  @override
  State<_FlowHost> createState() => _FlowHostState();
}

class _FlowHostState extends State<_FlowHost> {
  _FlowStep _step = _FlowStep.login;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _FlowStep.login:
        return AuthPage(
          onAuthenticated: () =>
              setState(() => _step = _FlowStep.completeProfile),
        );
      case _FlowStep.completeProfile:
        return CompleteProfilePage(
          onComplete: () => setState(() => _step = _FlowStep.checkIn),
          initialProfile: UserProfile(
            birthdate: '1995-01-01',
            gender: 'male',
            unitSystem: 'metric',
            height: 175,
          ),
        );
      case _FlowStep.checkIn:
        return CheckInPage(
          onComplete: () => setState(() => _step = _FlowStep.main),
        );
      case _FlowStep.main:
        return const MainScaffold(showTestControls: true);
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'critical flow: login -> profile -> check-in -> photo analysis -> quick add -> log/analysis with negative cases',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await mockPackageInfo();
      addTearDown(clearPluginMocks);

      final fakeStorage = FakeStorageService();
      final fakeSupabase = FakeSupabaseService();
      final fakeFoodAnalysis = FakeFoodAnalysisService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageProvider.overrideWith((ref) => fakeStorage),
            supabaseProvider.overrideWith((ref) => fakeSupabase),
            foodAnalysisServiceProvider.overrideWith((ref) => fakeFoodAnalysis),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const _FlowHost(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Login
      await tester.enterText(find.byType(TextField).at(0), 'user@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      // Complete profile (3 steps)
      final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(continueButton.first);
      await tester.tap(continueButton.first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(continueButton.first);
      await tester.tap(continueButton.first);
      await tester.pumpAndSettle();
      final saveProfileButton = find.widgetWithText(
        ElevatedButton,
        'Save & Start Tracking',
      );
      await tester.ensureVisible(saveProfileButton);
      await tester.tap(saveProfileButton);
      await tester.pumpAndSettle();

      // Daily check-in
      await tester.enterText(find.byType(TextField).at(0), '72.0');
      await tester.enterText(find.byType(TextField).at(1), '83.0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save & Continue'));
      await tester.pumpAndSettle();

      // Take photo + analyze meal (via deterministic test control)
      await tester.tap(find.byKey(const Key('main_nav_add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test_analyze_valid_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Meal'));
      await tester.pumpAndSettle();

      // Quick add flow
      await tester.tap(find.byKey(const Key('main_nav_add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('White Rice').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Meal'));
      await tester.pumpAndSettle();

      // View log
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Meals ('), findsOneWidget);

      // View analysis
      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsWidgets);

      // Negative case 1: invalid photo
      await tester.tap(find.byKey(const Key('main_nav_add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test_analyze_invalid_photo')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Invalid photo format'), findsOneWidget);

      // Negative case 2: network error handling
      final callsBeforeNetworkError = fakeFoodAnalysis.analyzeCallCount;
      fakeFoodAnalysis.shouldThrowNetworkError = true;
      await tester.tap(find.byKey(const Key('test_analyze_valid_photo')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        fakeFoodAnalysis.analyzeCallCount,
        greaterThan(callsBeforeNetworkError),
      );
      expect(find.text('Test Chicken Rice'), findsNothing);
    },
  );
}
