import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/models/meal.dart';

void main() {
  group('Meal (MealRecord domain model)', () {
    test('toJson and fromJson preserve values', () {
      final meal = Meal(
        id: 'meal-1',
        name: 'Chicken Rice',
        calories: 620,
        timestamp: 1710000000000,
        image: 'https://example.com/meal.jpg',
        imagePath: 'user-1/20260409/meal.jpg',
        protein: 30,
        carbs: 70,
        fat: 20,
        sugar: 6,
      );

      final restored = Meal.fromJson(meal.toJson());

      expect(restored.id, 'meal-1');
      expect(restored.name, 'Chicken Rice');
      expect(restored.calories, 620);
      expect(restored.timestamp, 1710000000000);
      expect(restored.image, 'https://example.com/meal.jpg');
      expect(restored.imagePath, 'user-1/20260409/meal.jpg');
      expect(restored.protein, 30);
      expect(restored.carbs, 70);
      expect(restored.fat, 20);
      expect(restored.sugar, 6);
    });

    test('copyWith updates selected fields only', () {
      final meal = Meal(
        id: 'meal-2',
        name: 'Original',
        calories: 500,
        timestamp: 1,
      );

      final updated = meal.copyWith(name: 'Updated', calories: 540, sugar: 4);

      expect(updated.id, 'meal-2');
      expect(updated.name, 'Updated');
      expect(updated.calories, 540);
      expect(updated.timestamp, 1);
      expect(updated.sugar, 4);
      expect(updated.imagePath, isNull);
    });
  });
}
