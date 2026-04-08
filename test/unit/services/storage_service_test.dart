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
