import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/env/env.dart';
import 'package:hk_food_calorie_ai/shared/services/food_analysis_service.dart';

void main() {
  group('FoodAnalysisService', () {
    test('returns normalized payload for flat ingredients response', () async {
      final service = FoodAnalysisService(
        uploadImage: (_) async => const UploadedImage(
          storagePath: 'user-1/20260409/photo.jpg',
          imageUrl: 'https://example.com/fallback.jpg',
        ),
        invokeAnalyze: (_, _) async => {
          'success': true,
          'analysis_id': 'analysis-123',
          'image': {
            'path': 'user-1/20260409/photo.jpg',
            'url': 'https://example.com/photo.jpg',
          },
          'meal_date': '2026-04-09',
          'ingredients': [
            {
              'name': 'Test Meal',
              'grams': 320,
              'ml': null,
              'calories': 500,
              'protein': 20,
              'carb': 60,
              'fat': 15,
              'sugar': 5,
              'confidence': 0.9,
            },
          ],
          'total_calories': 500,
          'total_mass': 320,
          'total_fat': 15,
          'total_carb': 60,
          'total_protein': 20,
          'total_sugar': 5,
        },
      );

      final result = await service.analyzeImage('meal.jpg');

      expect(result['name'], 'Test Meal');
      final meal = result['meal'] as Map<String, dynamic>;
      final totals = meal['totals'] as Map<String, dynamic>;
      final firstItem =
          (meal['items'] as List<dynamic>).first as Map<String, dynamic>;
      final portion = firstItem['portion'] as Map<String, dynamic>;
      expect(totals['calories'], 500);
      expect(totals['protein'], 20);
      expect(portion['size'], 1);
      expect(portion['unit'], 'g');
      expect(portion['grams'], 320);
      expect(portion['ml'], isNull);
      expect(
        (result['image'] as Map<String, dynamic>)['url'],
        'https://example.com/photo.jpg',
      );
      expect(
        (result['image'] as Map<String, dynamic>)['path'],
        'user-1/20260409/photo.jpg',
      );
      expect(result['analysis_id'], 'analysis-123');
      expect(meal['date'], '2026-04-09');
    });

    test(
      'normalizes drink portion with grams as null and ml as value',
      () async {
        final service = FoodAnalysisService(
          uploadImage: (_) async => const UploadedImage(
            storagePath: 'user-1/20260409/photo.jpg',
            imageUrl: 'https://example.com/fallback.jpg',
          ),
          invokeAnalyze: (_, _) async => {
            'success': true,
            'meal_date': '2026-04-09',
            'ingredients': [
              {
                'name': 'Milk Tea',
                'grams': 120,
                'ml': 350,
                'calories': 180,
                'protein': 4,
                'carb': 28,
                'fat': 6,
                'sugar': 24,
                'confidence': 0.92,
              },
            ],
            'total_calories': 180,
            'total_mass': 350,
            'total_fat': 6,
            'total_carb': 28,
            'total_protein': 4,
            'total_sugar': 24,
          },
        );

        final result = await service.analyzeImage('meal.jpg');

        final meal = result['meal'] as Map<String, dynamic>;
        final firstItem =
            (meal['items'] as List<dynamic>).first as Map<String, dynamic>;
        final portion = firstItem['portion'] as Map<String, dynamic>;
        expect(portion['grams'], isNull);
        expect(portion['ml'], 350);
      },
    );

    test(
      'rejects legacy nested meal payload when ingredients field is missing',
      () async {
        final service = FoodAnalysisService(
          uploadImage: (_) async => const UploadedImage(
            storagePath: 'user-1/20260409/photo.jpg',
            imageUrl: 'https://example.com/fallback.jpg',
          ),
          invokeAnalyze: (_, _) async => {
            'success': true,
            'meal': {
              'date': '2026-04-09',
              'items': [
                {
                  'name_en': 'Legacy Meal',
                  'name_zh': '舊格式餐',
                  'type': 'food',
                  'portion': {
                    'size': 1,
                    'unit': 'plate',
                    'grams': 280,
                    'ml': null,
                  },
                  'calories': 430,
                  'protein': 18,
                  'carbs': 54,
                  'fat': 13,
                  'sugar': 6,
                  'confidence': 0.88,
                },
              ],
              'totals': {
                'calories': 430,
                'protein': 18,
                'carbs': 54,
                'fat': 13,
                'sugar': 6,
              },
            },
          },
        );

        expect(
          () => service.analyzeImage('meal.jpg'),
          throwsA(
            isA<FoodAnalysisException>().having(
              (error) => error.message,
              'message',
              'Unexpected response from analysis service.',
            ),
          ),
        );
      },
    );

    test(
      'uses uploaded image url as fallback when server omits nested image url',
      () async {
        final service = FoodAnalysisService(
          uploadImage: (_) async => const UploadedImage(
            storagePath: 'user-1/20260409/photo.jpg',
            imageUrl: 'https://example.com/fallback.jpg',
          ),
          invokeAnalyze: (_, _) async => {
            'success': true,
            'meal_date': '2026-04-09',
            'ingredients': [
              {
                'name': 'Fallback Meal',
                'grams': 300,
                'ml': null,
                'calories': 420,
                'protein': 18,
                'carb': 52,
                'fat': 12,
                'sugar': 6,
                'confidence': 0.9,
              },
            ],
            'total_calories': 420,
            'total_mass': 300,
            'total_fat': 12,
            'total_carb': 52,
            'total_protein': 18,
            'total_sugar': 6,
          },
        );

        final result = await service.analyzeImage('meal.jpg');

        expect(
          (result['image'] as Map<String, dynamic>)['url'],
          'https://example.com/fallback.jpg',
        );
      },
    );

    test('passes storage path and iso date to invokeAnalyze', () async {
      String? capturedPath;
      String? capturedDate;

      final service = FoodAnalysisService(
        now: () => DateTime.utc(2026, 4, 9, 10, 30),
        uploadImage: (_) async => const UploadedImage(
          storagePath: 'user-1/20260409/photo.jpg',
          imageUrl: 'https://example.com/photo.jpg',
        ),
        invokeAnalyze: (imagePath, date) async {
          capturedPath = imagePath;
          capturedDate = date;
          return {
            'success': true,
            'meal_date': '2026-04-09',
            'ingredients': [
              {
                'name': 'Date Meal',
                'grams': 240,
                'ml': null,
                'calories': 300,
                'protein': 10,
                'carb': 40,
                'fat': 9,
                'sugar': 4,
                'confidence': 0.86,
              },
            ],
            'total_calories': 300,
            'total_mass': 240,
            'total_fat': 9,
            'total_carb': 40,
            'total_protein': 10,
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
          imageUrl: 'https://example.com/photo.jpg',
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

    test('maps gateway name resolution failure to clearer message', () async {
      final service = FoodAnalysisService(
        uploadImage: (_) async => const UploadedImage(
          storagePath: 'user-1/20260409/photo.jpg',
          imageUrl: 'https://example.com/photo.jpg',
        ),
        invokeAnalyze: (_, _) async => {
          'success': false,
          'message': 'name resolution failed',
        },
      );

      expect(
        () => service.analyzeImage('meal.jpg'),
        throwsA(
          isA<FoodAnalysisException>().having(
            (error) => error.message,
            'message',
            'Service routing is temporarily unavailable. Please retry in 10-30 seconds.',
          ),
        ),
      );
    });

    test(
      'rewrites internal signed image URL host to app Supabase base',
      () async {
        final service = FoodAnalysisService(
          uploadImage: (_) async => const UploadedImage(
            storagePath: 'user-1/20260409/photo.jpg',
            imageUrl: 'https://example.com/fallback.jpg',
          ),
          invokeAnalyze: (_, _) async => {
            'success': true,
            'image': {
              'path': 'user-1/20260409/photo.jpg',
              'url':
                  'http://kong:8000/storage/v1/object/sign/meal-images/user-1/20260409/photo.jpg?token=test-token',
            },
            'meal_date': '2026-04-09',
            'ingredients': [
              {
                'name': 'Internal Host Meal',
                'grams': 280,
                'ml': null,
                'calories': 450,
                'protein': 22,
                'carb': 55,
                'fat': 14,
                'sugar': 6,
                'confidence': 0.9,
              },
            ],
            'total_calories': 450,
            'total_mass': 280,
            'total_fat': 14,
            'total_carb': 55,
            'total_protein': 22,
            'total_sugar': 6,
          },
        );

        final result = await service.analyzeImage('meal.jpg');
        final imageUrl =
            (result['image'] as Map<String, dynamic>)['url'] as String;
        final normalizedUri = Uri.parse(imageUrl);
        final baseUri = Uri.parse(Env.supabaseUrl);

        expect(normalizedUri.scheme, baseUri.scheme);
        expect(normalizedUri.host, baseUri.host);
        expect(normalizedUri.hasPort, baseUri.hasPort);
        if (baseUri.hasPort) {
          expect(normalizedUri.port, baseUri.port);
        }
        expect(
          normalizedUri.path,
          '/storage/v1/object/sign/meal-images/user-1/20260409/photo.jpg',
        );
        expect(normalizedUri.query, 'token=test-token');
      },
    );
  });
}
