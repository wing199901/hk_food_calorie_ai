import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/models/quick_add_item.dart';

void main() {
  group('QuickAddItem', () {
    test('fromJson applies defaults for missing optional fields', () {
      final item = QuickAddItem.fromJson({
        'id': 'custom-1',
        'name': 'Tea',
        'calories': 40,
      });

      expect(item.protein, 0);
      expect(item.carbs, 0);
      expect(item.fat, 0);
      expect(item.sugar, 0);
      expect(item.icon, '🍽️');
    });

    test('copyWith updates selected fields only', () {
      final base = QuickAddItem(
        id: 'id',
        name: 'Rice',
        calories: 200,
        protein: 4,
        carbs: 45,
        fat: 1,
        sugar: 0,
        icon: '🍚',
      );

      final updated = base.copyWith(name: 'White Rice', calories: 230);

      expect(updated.id, 'id');
      expect(updated.name, 'White Rice');
      expect(updated.calories, 230);
      expect(updated.protein, 4);
      expect(updated.icon, '🍚');
    });

    test('defaults returns seeded default items with expected id prefix', () {
      final defaults = QuickAddItem.defaults;

      expect(defaults.length, greaterThanOrEqualTo(8));
      expect(defaults.every((item) => item.id.startsWith('default-')), isTrue);
    });
  });
}
