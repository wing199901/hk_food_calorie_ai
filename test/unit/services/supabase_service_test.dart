import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/meal.dart';
import 'package:hk_food_calorie_ai/shared/models/quick_add_item.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _UnauthenticatedSupabaseService extends SupabaseService {
  @override
  User? get currentUser => null;
}

void main() {
  group('SupabaseService', () {
    test('isAuthenticated is false without logged-in user', () {
      final service = _UnauthenticatedSupabaseService();
      expect(service.isAuthenticated, isFalse);
    });

    test(
      'throws StateError for profile operations when unauthenticated',
      () async {
        final service = _UnauthenticatedSupabaseService();

        expect(service.fetchProfile(), throwsA(isA<StateError>()));
        expect(
          service.saveProfile(UserProfile(gender: 'male')),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throws StateError for meal operations when unauthenticated',
      () async {
        final service = _UnauthenticatedSupabaseService();

        expect(service.fetchMeals(), throwsA(isA<StateError>()));
        expect(
          service.addMeal(
            Meal(
              id: '1',
              name: 'Meal',
              calories: 100,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ),
            mealDate: '2026-04-08',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throws StateError for body metric and quick add operations',
      () async {
        final service = _UnauthenticatedSupabaseService();

        expect(service.fetchBodyHistory(), throwsA(isA<StateError>()));
        expect(
          service.saveBodyMetric(BodyMetric(date: '2026-04-08')),
          throwsA(isA<StateError>()),
        );
        expect(service.fetchQuickAddItems(), throwsA(isA<StateError>()));
        expect(
          service.addQuickAddItem(
            QuickAddItem(
              id: 'q1',
              name: 'Item',
              calories: 100,
              protein: 1,
              carbs: 1,
              fat: 1,
              sugar: 1,
              icon: 'I',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('fetchAllUserData throws StateError when unauthenticated', () async {
      final service = _UnauthenticatedSupabaseService();
      expect(service.fetchAllUserData(), throwsA(isA<StateError>()));
    });
  });
}
