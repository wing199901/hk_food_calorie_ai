// Tests for CompleteProfilePage covering:
//  - Step navigation (1 → 2 → 3)
//  - Step 1 validation (birthdate required)
//  - Step 2 "Continue" advances to Step 3
//  - Step 3 "Save & Start Tracking" saves profile and calls onComplete
//  - Empty Step 2 saves null weight/target weight/waistline (no default injection)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';
import 'package:hk_food_calorie_ai/features/onboarding/complete_profile_page.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/storage_provider.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';

// ---------------------------------------------------------------------------
// Fake StorageService — stores data in memory, no SharedPreferences needed.
// ---------------------------------------------------------------------------

class FakeStorageService extends StorageService {
  UserProfile _profile = UserProfile();
  final List<UserProfile> savedProfiles = [];
  final List<BodyMetric> savedMetrics = [];
  String? lastCheckInDate;

  @override
  UserProfile getUserProfile() => _profile;

  @override
  Future<void> setUserProfile(UserProfile profile) async {
    _profile = profile;
    savedProfiles.add(profile);
    notifyListeners();
  }

  @override
  void addBodyMetric(BodyMetric metric) {
    savedMetrics.add(metric);
  }

  @override
  void setLastCheckInDate(String dateStr) {
    lastCheckInDate = dateStr;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget buildPage({
  required FakeStorageService storage,
  required VoidCallback onComplete,
}) {
  return ProviderScope(
    overrides: [storageProvider.overrideWith((ref) => storage)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: CompleteProfilePage(onComplete: onComplete),
    ),
  );
}

/// Opens the birthdate picker and taps "Done" to confirm the default date.
Future<void> confirmBirthdate(WidgetTester tester) async {
  await tester.tap(find.text('Select your birthdate'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

/// Scrolls a widget into view and taps it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the final save/skip button and pumps enough for the async save to
/// complete. Must NOT use pumpAndSettle because _isSaving stays true after
/// save, keeping a CircularProgressIndicator alive which never settles.
Future<void> tapSaveButton(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump(); // kick off async
  await tester.pump(const Duration(milliseconds: 300)); // complete save
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CompleteProfilePage', () {
    late FakeStorageService fakeStorage;
    late bool completeCalled;

    setUp(() {
      fakeStorage = FakeStorageService();
      completeCalled = false;
    });

    // Use a tall phone-like canvas (540×1200 logical px) so all content fits.
    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    // ── Step 1 ──────────────────────────────────────────────────────────────

    testWidgets('Step 1 is shown on first load', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Select your birthdate'), findsOneWidget);
    });

    testWidgets('Step 1 Continue without birthdate shows validation error', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      await scrollAndTap(tester, find.text('Continue'));
      expect(find.text('Please enter your birthdate.'), findsOneWidget);
      // Still on step 1
      expect(find.text('Complete Your Profile'), findsOneWidget);
    });

    testWidgets('Step 1 Continue with birthdate advances to Step 2', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      await confirmBirthdate(tester);
      await scrollAndTap(tester, find.text('Continue'));
      expect(find.text('Almost There!'), findsOneWidget);
    });

    // ── Step 2 ──────────────────────────────────────────────────────────────

    testWidgets('Step 2 Continue advances to Step 3', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      await confirmBirthdate(tester);
      await scrollAndTap(tester, find.text('Continue'));
      // On Step 2
      expect(find.text('Almost There!'), findsOneWidget);
      await scrollAndTap(tester, find.text('Continue'));
      expect(find.text('One Last Thing'), findsOneWidget);
    });

    // ── Step 3 ──────────────────────────────────────────────────────────────

    testWidgets(
      'Step 3 "Save & Start Tracking" saves profile and calls onComplete',
      (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          buildPage(
            storage: fakeStorage,
            onComplete: () => completeCalled = true,
          ),
        );
        await confirmBirthdate(tester);
        await scrollAndTap(tester, find.text('Continue'));
        await scrollAndTap(tester, find.text('Continue'));
        // On Step 3
        await tapSaveButton(tester, find.text('Save & Start Tracking'));

        expect(completeCalled, isTrue);
        expect(fakeStorage.savedProfiles, isNotEmpty);
      },
    );

    // ── Regression: null weight/waistline when Step 2 fields left empty ──────

    testWidgets('Empty Step 2 saves null weight, target weight and waistline', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      await confirmBirthdate(tester);
      await scrollAndTap(tester, find.text('Continue'));
      // Continue on Step 2 with empty weight/waistline fields
      await scrollAndTap(tester, find.text('Continue'));
      // Save on Step 3
      await tapSaveButton(tester, find.text('Save & Start Tracking'));

      expect(fakeStorage.savedProfiles, isNotEmpty);
      final saved = fakeStorage.savedProfiles.last;
      expect(
        saved.weight,
        isNull,
        reason: 'Weight should be null when left empty on Step 2',
      );
      expect(
        saved.targetWeight,
        isNull,
        reason: 'Target weight should be null when left empty on Step 2',
      );
      expect(
        saved.waistline,
        isNull,
        reason: 'Waistline should be null when left empty on Step 2',
      );
    });

    testWidgets('Entering weight on Step 2 saves it correctly', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      await confirmBirthdate(tester);
      await scrollAndTap(tester, find.text('Continue'));
      // Enter weight on Step 2
      await tester.enterText(find.widgetWithText(TextField, '70'), '65');
      await scrollAndTap(tester, find.text('Continue'));
      // Save on Step 3
      await tapSaveButton(tester, find.text('Save & Start Tracking'));

      expect(fakeStorage.savedProfiles, isNotEmpty);
      expect(fakeStorage.savedProfiles.last.weight, 65.0);
    });

    testWidgets('Entering target weight saves goal target', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );
      await confirmBirthdate(tester);
      await scrollAndTap(tester, find.text('Continue'));
      await tester.enterText(find.widgetWithText(TextField, '65'), '60');
      await scrollAndTap(tester, find.text('Continue'));
      await tapSaveButton(tester, find.text('Save & Start Tracking'));

      expect(fakeStorage.savedProfiles, isNotEmpty);
      expect(fakeStorage.savedProfiles.last.targetWeight, 60.0);
    });

    testWidgets('Step 2 auto-calculates goal amount from target weight', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        buildPage(
          storage: fakeStorage,
          onComplete: () => completeCalled = true,
        ),
      );

      await confirmBirthdate(tester);
      await scrollAndTap(tester, find.text('Continue'));

      await tester.enterText(find.byType(TextField).at(0), '70');
      await tester.enterText(find.byType(TextField).at(1), '65');
      await tester.pump();

      expect(
        find.text('Healthy range: 56.7 kg~ 70.5 kg'),
        findsOneWidget,
      );

      final loseGoal = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText() == 'Goal: -5.0 kg, 21.2 BMI',
        ),
      );
      final loseGoalSpan = loseGoal.text as TextSpan;
      expect(loseGoalSpan.style?.color, AppTheme.foreground);
      expect(loseGoalSpan.children, hasLength(2));
      final loseGoalValue = loseGoalSpan.children!.last as TextSpan;
      expect(loseGoalValue.style?.color, AppTheme.accent);

      await tester.enterText(find.byType(TextField).at(1), '75');
      await tester.pump();
      final gainGoal = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText() == 'Goal: +5.0 kg, 24.5 BMI',
        ),
      );
      final gainGoalSpan = gainGoal.text as TextSpan;
      final gainGoalValue = gainGoalSpan.children!.last as TextSpan;
      expect(gainGoalValue.style?.color, AppTheme.primary);

      await tester.enterText(find.byType(TextField).at(1), '70');
      await tester.pump();
      final maintainGoal = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText() == 'Goal: 0.0 kg, 22.9 BMI',
        ),
      );
      final maintainGoalSpan = maintainGoal.text as TextSpan;
      final maintainGoalValue = maintainGoalSpan.children!.last as TextSpan;
      expect(maintainGoalValue.style?.color, AppTheme.mutedForeground);
    });

    testWidgets(
      'Step 2 direction hint appears before both weights are entered',
      (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          buildPage(
            storage: fakeStorage,
            onComplete: () => completeCalled = true,
          ),
        );

        await confirmBirthdate(tester);
        await scrollAndTap(tester, find.text('Continue'));

        expect(
          find.text('Set your target weight and we auto-calculate direction.'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField).at(0), '70');
        await tester.pump();

        expect(
          find.text('Set your target weight and we auto-calculate direction.'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField).at(1), '68');
        await tester.pump();
        final finalGoal = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText() == 'Goal: -2.0 kg, 22.2 BMI',
          ),
        );
        final finalGoalSpan = finalGoal.text as TextSpan;
        final finalGoalValue = finalGoalSpan.children!.last as TextSpan;
        expect(finalGoalValue.style?.color, AppTheme.accent);
      },
    );
  });
}
