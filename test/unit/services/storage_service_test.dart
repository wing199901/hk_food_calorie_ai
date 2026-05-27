import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/meal.dart';
import 'package:hk_food_calorie_ai/shared/models/quick_add_item.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_supabase_service.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(supabaseService: FakeSupabaseService());
    await storage.init();
  });

  group('StorageService', () {
    int expectedTee({
      required double weight,
      required String gender,
      required int age,
      required String activityLevel,
    }) {
      double bmr;
      if (gender == 'male') {
        if (age < 30) {
          bmr = 15.3 * weight + 679;
        } else if (age < 60) {
          bmr = 11.6 * weight + 879;
        } else {
          bmr = 13.5 * weight + 487;
        }
      } else if (gender == 'female') {
        if (age < 30) {
          bmr = 14.7 * weight + 496;
        } else if (age < 60) {
          bmr = 8.7 * weight + 829;
        } else {
          bmr = 10.5 * weight + 596;
        }
      } else {
        double maleBmr;
        double femaleBmr;
        if (age < 30) {
          maleBmr = 15.3 * weight + 679;
          femaleBmr = 14.7 * weight + 496;
        } else if (age < 60) {
          maleBmr = 11.6 * weight + 879;
          femaleBmr = 8.7 * weight + 829;
        } else {
          maleBmr = 13.5 * weight + 487;
          femaleBmr = 10.5 * weight + 596;
        }
        bmr = (maleBmr + femaleBmr) / 2;
      }

      const activityMultipliers = {
        'sedentary': 1.2,
        'light': 1.375,
        'moderate': 1.55,
        'active': 1.725,
        'very-active': 1.9,
      };

      return (bmr * (activityMultipliers[activityLevel] ?? 1.55)).round();
    }

    test('uses 2000 as default daily target', () {
      expect(storage.getDailyTarget(), 2000);
    });

    test('saveMeal updates meals and date stats', () {
      final timestamp = DateTime(2026, 4, 8, 12).millisecondsSinceEpoch;
      storage.saveMeal(
        Meal(
          id: 'meal-1',
          name: 'Chicken Rice',
          calories: 600,
          protein: 30,
          carbs: 70,
          fat: 20,
          timestamp: timestamp,
        ),
      );

      final meals = storage.getMeals();
      final stats = storage.getStatsForDate(DateTime(2026, 4, 8));

      expect(meals, hasLength(1));
      expect(stats['consumed'], 600);
      expect(stats['remaining'], storage.getDailyTarget() - 600);
    });

    test(
      'setUserProfile persists profile and recalculates calorie target',
      () async {
        final profile = UserProfile(
          birthdate: '1995-01-01',
          gender: 'male',
          weight: 72,
          height: 175,
          activityLevel: 'moderate',
          unitSystem: 'metric',
        );

        await storage.setUserProfile(profile);

        final expectedTarget = StorageService.calculateTEE(profile);
        expect(storage.getUserProfile().height, 175);
        expect(storage.getDailyTarget(), expectedTarget);
      },
    );

    test(
      'target weight produces intake range and uses max as target',
      () async {
        final profile = UserProfile(
          birthdate: '1992-03-12',
          gender: 'female',
          weight: 78,
          targetWeight: 65,
          height: 165,
          activityLevel: 'light',
          unitSystem: 'metric',
        );

        await storage.setUserProfile(profile);

        final range = StorageService.calculateCalorieIntakeRange(profile);
        final storedRange = storage.getDailyTargetRange();

        expect(storage.getDailyTarget(), range.max);
        expect(storedRange.min, range.min);
        expect(storedRange.max, range.max);
        expect(range.min <= range.max, isTrue);
      },
    );

    test('gain goal max TEE clamps light activity to moderate', () {
      final profile = UserProfile(
        birthdate: '1992-03-12',
        gender: 'female',
        weight: 60,
        targetWeight: 68,
        height: 165,
        activityLevel: 'light',
      );

      final range = StorageService.calculateCalorieIntakeRange(profile);
      final expectedModerateGoalTee = StorageService.calculateTEE(
        profile.copyWith(
          weight: profile.targetWeight,
          activityLevel: 'moderate',
        ),
      );

      expect(range.max, expectedModerateGoalTee);
    });

    test('gain goal keeps higher activity levels', () {
      final profile = UserProfile(
        birthdate: '1992-03-12',
        gender: 'female',
        weight: 60,
        targetWeight: 68,
        height: 165,
        activityLevel: 'active',
      );

      final range = StorageService.calculateCalorieIntakeRange(profile);
      final expectedActiveGoalTee = StorageService.calculateTEE(
        profile.copyWith(weight: profile.targetWeight),
      );

      expect(range.max, expectedActiveGoalTee);
    });

    test('calculates Devine IBW for male and female', () {
      final maleIbw = StorageService.calculateDevineIbwKg(
        heightCm: 175,
        gender: 'male',
      );
      final femaleIbw = StorageService.calculateDevineIbwKg(
        heightCm: 165,
        gender: 'female',
      );

      expect(maleIbw, closeTo(70.5, 0.1));
      expect(femaleIbw, closeTo(56.9, 0.1));
    });

    test('calculates healthy range from BMI 18.5 weight to Devine IBW', () {
      final guide = StorageService.calculateHealthyWeightGuide(
        heightCm: 175,
        gender: 'male',
      );

      expect(guide, isNotNull);
      expect(guide!.minKg, closeTo(56.7, 0.1));
      expect(guide.maxKg, closeTo(70.5, 0.1));
    });

    test('calculateTEE uses ABW when above 120% IBW', () {
      final profile = UserProfile(
        gender: 'male',
        height: 175,
        weight: 100,
        activityLevel: 'moderate',
      );

      final ibw = StorageService.calculateDevineIbwKg(
        heightCm: profile.height,
        gender: profile.gender,
      );
      final abw = ibw! + 0.4 * (profile.weight! - ibw);
      final expected = expectedTee(
        weight: abw,
        gender: 'male',
        age: 25,
        activityLevel: 'moderate',
      );

      expect(StorageService.calculateTEE(profile), expected);
    });

    test('calculateTEE uses actual weight at or below 120% IBW', () {
      final profile = UserProfile(
        gender: 'male',
        height: 175,
        weight: 80,
        activityLevel: 'moderate',
      );

      final expected = expectedTee(
        weight: 80,
        gender: 'male',
        age: 25,
        activityLevel: 'moderate',
      );

      expect(StorageService.calculateTEE(profile), expected);
    });

    test('addBodyMetric auto-computes bmi, whtr and tee', () async {
      await storage.setUserProfile(
        UserProfile(
          birthdate: '1990-01-01',
          gender: 'female',
          height: 170,
          weight: 65,
          waistline: 78,
          activityLevel: 'light',
        ),
      );

      storage.addBodyMetric(
        BodyMetric(date: '2026-04-08', weight: 68, waistline: 84),
      );

      final history = storage.getBodyHistory();
      expect(history, hasLength(1));
      expect(history.first.bmi, closeTo(23.5, 0.1));
      expect(history.first.whtr, closeTo(0.49, 0.01));
      expect(history.first.tee, isNotNull);
    });

    test('addBodyMetric keeps same-day changes in history', () async {
      await storage.setUserProfile(
        UserProfile(
          birthdate: '1990-01-01',
          gender: 'female',
          height: 170,
          weight: 65,
          waistline: 78,
          activityLevel: 'light',
        ),
      );

      storage.addBodyMetric(
        BodyMetric(date: '2026-04-08', weight: 68, waistline: 84),
      );
      storage.addBodyMetric(BodyMetric(date: '2026-04-08', weight: 67.5));

      final sameDayHistory = storage
          .getBodyHistory()
          .where((m) => m.date == '2026-04-08')
          .toList();

      expect(sameDayHistory, hasLength(2));
      expect(sameDayHistory.last.weight, closeTo(67.5, 0.01));
      expect(sameDayHistory.last.waistline, closeTo(84, 0.01));
      expect(sameDayHistory.last.createdAt, isNotNull);
    });

    test('getQuickAddItems seeds defaults and enforces dedupe on add', () {
      final initial = storage.getQuickAddItems();
      final duplicate = QuickAddItem(
        id: 'custom-duplicate',
        name: initial.first.name.toUpperCase(),
        calories: 99,
        protein: 1,
        carbs: 1,
        fat: 1,
        sugar: 1,
        icon: 'X',
      );

      storage.addQuickAddItem(duplicate);
      final after = storage.getQuickAddItems();

      expect(initial, isNotEmpty);
      expect(after.length, initial.length);
    });

    test('getRangeData returns one entry per day with macro totals', () {
      storage.saveMeal(
        Meal(
          id: 'm1',
          name: 'Meal A',
          calories: 400,
          protein: 20,
          carbs: 50,
          fat: 10,
          timestamp: DateTime(2026, 4, 1, 12).millisecondsSinceEpoch,
        ),
      );
      storage.saveMeal(
        Meal(
          id: 'm2',
          name: 'Meal B',
          calories: 350,
          protein: 15,
          carbs: 45,
          fat: 12,
          timestamp: DateTime(2026, 4, 2, 12).millisecondsSinceEpoch,
        ),
      );

      final range = storage.getRangeData(DateTime(2026, 4, 1), 3);

      expect(range, hasLength(3));
      expect(range[0]['calories'], 400);
      expect(range[1]['protein'], 15);
      expect(range[2]['calories'], 0);
    });
  });
}
