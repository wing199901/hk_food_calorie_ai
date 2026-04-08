import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/services/food_analysis_service.dart';

void main() {
  group('FoodAnalysisService', () {
    test('returns analysis payload for valid image', () async {
      final service = FoodAnalysisService(
        random: Random(1),
        simulatedLatency: Duration.zero,
        foodDatabase: const [
          {
            'name': 'Test Meal',
            'calories': 500,
            'protein': 20,
            'carbs': 60,
            'fat': 15,
            'sugar': 5,
          },
        ],
      );

      final result = await service.analyzeImage('meal.jpg');

      expect(result['name'], 'Test Meal');
      expect(result['calories'], 500);
      expect(result['protein'], 20);
    });

    test('throws for blank image path', () async {
      final service = FoodAnalysisService(simulatedLatency: Duration.zero);

      expect(
        () => service.analyzeImage('   '),
        throwsA(isA<FoodAnalysisException>()),
      );
    });

    test('throws for unsupported image extension', () async {
      final service = FoodAnalysisService(simulatedLatency: Duration.zero);

      expect(
        () => service.analyzeImage('meal.txt'),
        throwsA(isA<FoodAnalysisException>()),
      );
    });

    test('throws network error when failure rate is 1.0', () async {
      final service = FoodAnalysisService(
        random: Random(1),
        simulatedLatency: Duration.zero,
        simulatedFailureRate: 1,
      );

      expect(
        () => service.analyzeImage('meal.jpg'),
        throwsA(isA<FoodAnalysisException>()),
      );
    });
  });
}
