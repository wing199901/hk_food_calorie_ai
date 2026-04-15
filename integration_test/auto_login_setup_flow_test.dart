import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';
import 'package:hk_food_calorie_ai/features/auth/auth_page.dart';
import 'package:hk_food_calorie_ai/features/check_in/check_in_page.dart';
import 'package:hk_food_calorie_ai/features/onboarding/complete_profile_page.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';
import 'package:hk_food_calorie_ai/shared/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _testEmail = String.fromEnvironment(
  'TEST_EMAIL',
  defaultValue: 'test@example.com',
);
const _testPassword = String.fromEnvironment(
  'TEST_PASSWORD',
  defaultValue: '12345678',
);

const _setupBirthdate = '1999-11-10';
const _setupGender = 'male';
const _setupUnitSystem = 'metric';
const _setupHeightCm = 175.0;
const _setupWeightKg = 45.0;
const _setupPreferredWeightKg = 42.0;
const _setupWaistlineCm = 45.0;
const _setupActivityLevel = 'sedentary';

enum _SetupFlowStep { login, completeProfile, checkIn, done }

class _SetupFlowHost extends StatefulWidget {
  const _SetupFlowHost();

  @override
  State<_SetupFlowHost> createState() => _SetupFlowHostState();
}

class _SetupFlowHostState extends State<_SetupFlowHost> {
  _SetupFlowStep _step = _SetupFlowStep.login;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _SetupFlowStep.login:
        return AuthPage(
          onAuthenticated: () {
            setState(() => _step = _SetupFlowStep.completeProfile);
          },
        );
      case _SetupFlowStep.completeProfile:
        return CompleteProfilePage(
          onComplete: () {
            setState(() => _step = _SetupFlowStep.checkIn);
          },
          initialProfile: UserProfile(
            birthdate: _setupBirthdate,
            gender: _setupGender,
            unitSystem: _setupUnitSystem,
            height: _setupHeightCm,
            weight: _setupWeightKg,
            preferredWeight: _setupPreferredWeightKg,
            waistline: _setupWaistlineCm,
            activityLevel: _setupActivityLevel,
          ),
        );
      case _SetupFlowStep.checkIn:
        return CheckInPage(
          onComplete: () {
            setState(() => _step = _SetupFlowStep.done);
          },
        );
      case _SetupFlowStep.done:
        return const Scaffold(body: Center(child: Text('Setup Complete')));
    }
  }
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {
    await SupabaseService.initialize();
  }
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure('Timed out waiting for widget: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto login test account and complete setup flow', (
    tester,
  ) async {
    await _ensureSupabaseInitialized();

    final supabase = SupabaseService();
    await supabase.signOut();
    addTearDown(() async {
      await supabase.signOut();
    });

    final storage = StorageService(supabaseService: supabase);
    await storage.init();
    storage.clearAllLocalData();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWith((ref) => storage),
          supabaseProvider.overrideWith((ref) => supabase),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const _SetupFlowHost(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), _testEmail);
    await tester.enterText(find.byType(TextField).at(1), _testPassword);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));

    await _pumpUntilVisible(tester, find.text('Complete Your Profile'));

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

    await _pumpUntilVisible(tester, find.text('Daily Check-in'));

    await tester.enterText(
      find.byType(TextField).at(0),
      _setupWeightKg.toStringAsFixed(0),
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      _setupWaistlineCm.toStringAsFixed(0),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save & Continue'));

    await _pumpUntilVisible(tester, find.text('Setup Complete'));

    final profile = storage.getUserProfile();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bodyHistory = storage.getBodyHistory();
    final latestMetric = bodyHistory.last;

    expect(profile.isProfileComplete, isTrue);
    expect(profile.birthdate, _setupBirthdate);
    expect(profile.gender, _setupGender);
    expect(profile.unitSystem, _setupUnitSystem);
    expect(profile.activityLevel, _setupActivityLevel);
    expect(profile.height, closeTo(_setupHeightCm, 0.01));
    expect(profile.weight, closeTo(_setupWeightKg, 0.01));
    expect(profile.preferredWeight, closeTo(_setupPreferredWeightKg, 0.01));
    expect(profile.waistline, closeTo(_setupWaistlineCm, 0.01));

    expect(storage.getLastCheckInDate(), today);
    expect(bodyHistory, isNotEmpty);
    expect(latestMetric.date, today);
    expect(latestMetric.weight, closeTo(_setupWeightKg, 0.01));
    expect(latestMetric.waistline, closeTo(_setupWaistlineCm, 0.01));
  });
}
