import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_spacing.dart';
import 'package:hk_food_calorie_ai/core/utils/unit_converter.dart';
import 'package:hk_food_calorie_ai/features/analysis/pages/all_recorded_data_page.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/meal.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_storage_service.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'uses fixed page title and unit section title for weight metric',
    (tester) async {
      final now = DateTime.now();
      final dateWithTime = DateTime(now.year, 4, 10, 9, 30);

      final fakeStorage = FakeStorageService(
        profile: UserProfile(unitSystem: 'metric', height: 175),
        bodyHistory: [
          BodyMetric(
            date: '2026-04-10',
            weight: 70,
            createdAt: dateWithTime.toIso8601String(),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
          child: const AllRecordedDataPage(dataType: DataType.weight),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Recorded Data'), findsOneWidget);
      expect(find.text('All Recorded Weight'), findsNothing);

      expect(find.text('kg'), findsOneWidget);
      expect(find.text('70.0'), findsOneWidget);
      expect(find.text('70.0 kg'), findsNothing);

      final listCard = find.byKey(const Key('all_recorded_list_card'));
      final cardContainer = tester.widget<Container>(listCard);
      expect(
        cardContainer.padding,
        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      );
      expect(
        find.descendant(
          of: listCard,
          matching: find.byKey(const Key('all_recorded_unit_title')),
        ),
        findsNothing,
      );

      final expectedDate = DateFormat("dd MMM 'at' HH:mm").format(dateWithTime);
      expect(find.text(expectedDate), findsOneWidget);

      final unitTitlePadding = tester.widget<Padding>(
        find.byKey(const Key('all_recorded_unit_title_padding')),
      );
      expect(
        unitTitlePadding.padding,
        const EdgeInsets.only(left: AppSpacing.md),
      );
    },
  );

  testWidgets('converts weight to imperial and keeps list value unitless', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService(
      profile: UserProfile(unitSystem: 'imperial', height: 175),
      bodyHistory: [BodyMetric(date: '2026-04-10', weight: 70)],
    );
    final expectedLbs = UnitConverter.kgToLbs(70).toStringAsFixed(1);

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: const AllRecordedDataPage(dataType: DataType.weight),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('lbs'), findsOneWidget);
    expect(find.text(expectedLbs), findsOneWidget);
    expect(find.text('$expectedLbs lbs'), findsNothing);
  });

  testWidgets('shows height unit title from profile unit system', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService(
      profile: UserProfile(unitSystem: 'imperial', height: 180),
      bodyHistory: const [],
    );
    final expectedFeet = UnitConverter.cmToFt(180).toStringAsFixed(1);

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: const AllRecordedDataPage(dataType: DataType.height),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ft'), findsOneWidget);
    expect(find.text(expectedFeet), findsOneWidget);
    expect(find.text('$expectedFeet ft'), findsNothing);
  });

  testWidgets('shows year in date when item is not in current year', (
    tester,
  ) async {
    final now = DateTime.now();
    final oldDateWithTime = DateTime(now.year - 1, 2, 3, 7, 5);
    final fakeStorage = FakeStorageService(
      profile: UserProfile(unitSystem: 'metric', height: 175),
      bodyHistory: [
        BodyMetric(
          date: '2025-02-03',
          weight: 72,
          createdAt: oldDateWithTime.toIso8601String(),
        ),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: const AllRecordedDataPage(dataType: DataType.weight),
      ),
    );
    await tester.pumpAndSettle();

    final expectedDate = DateFormat(
      "dd MMM yyyy 'at' HH:mm",
    ).format(oldDateWithTime);
    expect(find.text(expectedDate), findsOneWidget);
  });

  testWidgets('opens details page on body row tap and shows user entered yes', (
    tester,
  ) async {
    final now = DateTime.now();
    final detailDate = DateTime(now.year, 3, 25, 1, 38, 0);
    final fakeStorage = FakeStorageService(
      profile: UserProfile(unitSystem: 'metric', height: 176),
      bodyHistory: [
        BodyMetric(
          date: DateFormat('yyyy-MM-dd').format(detailDate),
          weight: 70,
          createdAt: detailDate.toIso8601String(),
        ),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: const AllRecordedDataPage(dataType: DataType.weight),
      ),
    );
    await tester.pumpAndSettle();

    final listDate = DateFormat("dd MMM 'at' HH:mm").format(detailDate);
    await tester.tap(find.text(listDate));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Sample Details'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('70.0 kg'), findsOneWidget);
    expect(find.text('Date Added'), findsOneWidget);
    expect(find.text('Was User Entered'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Source'), findsNothing);
  });

  testWidgets('marks AI analyzed day as not user entered in energy details', (
    tester,
  ) async {
    final now = DateTime.now();
    final mealDate = DateTime(now.year, 4, 9, 21, 28);
    final fakeStorage = FakeStorageService(
      profile: UserProfile(unitSystem: 'metric', height: 175),
      meals: [
        Meal(
          id: 'meal-1',
          name: 'AI Scanned Meal',
          calories: 500,
          protein: 20,
          carbs: 50,
          fat: 10,
          timestamp: mealDate.millisecondsSinceEpoch,
          image: 'https://example.com/meal.jpg',
        ),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: const AllRecordedDataPage(dataType: DataType.energy),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('500 / 2000'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Energy Intake'), findsOneWidget);
    expect(find.text('500 / 2000 kcal'), findsOneWidget);
    expect(find.text('Was User Entered'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });
}
