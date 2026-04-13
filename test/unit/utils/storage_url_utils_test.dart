import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/utils/storage_url_utils.dart';

void main() {
  const appBaseUrl = 'http://127.0.0.1:54321';

  group('normalizeStorageUrl', () {
    test('prefixes base URL for relative storage path', () {
      final normalized = normalizeStorageUrl(
        '/storage/v1/object/sign/meal-images/user-1/path.jpg?token=abc',
        baseUrl: appBaseUrl,
      );

      expect(
        normalized,
        'http://127.0.0.1:54321/storage/v1/object/sign/meal-images/user-1/path.jpg?token=abc',
      );
    });

    test('rewrites internal host for storage signed URL', () {
      final normalized = normalizeStorageUrl(
        'http://kong:8000/storage/v1/object/sign/meal-images/user-1/path.jpg?token=abc',
        baseUrl: appBaseUrl,
      );

      expect(
        normalized,
        'http://127.0.0.1:54321/storage/v1/object/sign/meal-images/user-1/path.jpg?token=abc',
      );
    });

    test('keeps non-storage absolute URL unchanged', () {
      const externalUrl = 'https://example.com/image.jpg';

      final normalized = normalizeStorageUrl(externalUrl, baseUrl: appBaseUrl);

      expect(normalized, externalUrl);
    });

    test('keeps storage URL unchanged when already on app base host', () {
      const appUrl =
          'http://127.0.0.1:54321/storage/v1/object/sign/meal-images/user-1/path.jpg?token=abc';

      final normalized = normalizeStorageUrl(appUrl, baseUrl: appBaseUrl);

      expect(normalized, appUrl);
    });
  });
}
