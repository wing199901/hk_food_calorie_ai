import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/services/food_analysis_service.dart';

void main() {
  group('FoodAnalysisService', () {
    test('returns normalized payload for valid server response', () async {
      final service = FoodAnalysisService(
        uploadImage: (_) async => const UploadedImage(
          storagePath: 'user-1/20260409/photo.jpg',
          publicUrl: 'https://example.com/fallback.jpg',
        ),
        invokeAnalyze: (_, _) async => {
          'success': true,
          'image_url': 'https://example.com/photo.jpg',
          'items': [
            {'name_en': 'Test Meal', 'name_zh': '測試餐'},
          ],
          'total_calories': 500,
          'total_protein': 20,
          'total_carbs': 60,
          'total_fat': 15,
          'total_sugar': 5,
        },
      );

      final result = await service.analyzeImage('meal.jpg');

      expect(result['name'], 'Test Meal');
      expect(result['calories'], 500);
      expect(result['protein'], 20);
      expect(result['image_url'], 'https://example.com/photo.jpg');
    });

    test(
      'uses uploaded image url as fallback when server omits image_url',
      () async {
        final service = FoodAnalysisService(
          uploadImage: (_) async => const UploadedImage(
            storagePath: 'user-1/20260409/photo.jpg',
            publicUrl: 'https://example.com/fallback.jpg',
          ),
          invokeAnalyze: (_, _) async => {
            'success': true,
            'items': [
              {'name_en': 'Fallback Meal', 'name_zh': '後備餐'},
            ],
            'total_calories': 420,
            'total_protein': 18,
            'total_carbs': 52,
            'total_fat': 12,
            'total_sugar': 6,
          },
        );

        final result = await service.analyzeImage('meal.jpg');

        expect(result['image_url'], 'https://example.com/fallback.jpg');
      },
    );

    test('passes storage path and iso date to invokeAnalyze', () async {
      String? capturedPath;
      String? capturedDate;

      final service = FoodAnalysisService(
        now: () => DateTime.utc(2026, 4, 9, 10, 30),
        uploadImage: (_) async => const UploadedImage(
          storagePath: 'user-1/20260409/photo.jpg',
          publicUrl: 'https://example.com/photo.jpg',
        ),
        invokeAnalyze: (imagePath, date) async {
          capturedPath = imagePath;
          capturedDate = date;
          return {
            'success': true,
            'items': [
              {'name_en': 'Date Meal', 'name_zh': '日期餐'},
            ],
            'total_calories': 300,
            'total_protein': 10,
            'total_carbs': 40,
            'total_fat': 9,
            'total_sugar': 4,
          };
        },
      );

      await service.analyzeImage('meal.jpg');

      expect(capturedPath, 'user-1/20260409/photo.jpg');
      expect(capturedDate, '2026-04-09');
    });

    test('throws for blank image path', () async {
      final service = FoodAnalysisService();

      expect(
        () => service.analyzeImage('   '),
        throwsA(isA<FoodAnalysisException>()),
      );
    });

    test('throws for unsupported image extension', () async {
      final service = FoodAnalysisService();

      expect(
        () => service.analyzeImage('meal.txt'),
        throwsA(isA<FoodAnalysisException>()),
      );
    });

    test('throws mapped NO_FOOD_DETECTED error from server', () async {
      final service = FoodAnalysisService(
        uploadImage: (_) async => const UploadedImage(
          storagePath: 'user-1/20260409/photo.jpg',
          publicUrl: 'https://example.com/photo.jpg',
        ),
        invokeAnalyze: (_, _) async => {
          'success': false,
          'code': 'NO_FOOD_DETECTED',
          'error': 'No food found in the photo.',
        },
      );

      expect(
        () => service.analyzeImage('meal.jpg'),
        throwsA(
          isA<FoodAnalysisException>().having(
            (error) => error.message,
            'message',
            contains('No food found in the photo.'),
          ),
        ),
      );
    });
  });
}
