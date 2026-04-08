import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';
import 'package:hk_food_calorie_ai/shared/services/food_analysis_service.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';
import 'package:hk_food_calorie_ai/shared/services/supabase_service.dart';

import '../../helpers/fake_storage_service.dart';

void main() {
  group('Providers', () {
    test('storageProvider exposes StorageService by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(storageProvider), isA<StorageService>());
    });

    test('storageProvider can be overridden', () {
      final fakeStorage = FakeStorageService();
      final container = ProviderContainer(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
      );
      addTearDown(container.dispose);

      expect(identical(container.read(storageProvider), fakeStorage), isTrue);
    });

    test('supabaseProvider exposes SupabaseService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(supabaseProvider), isA<SupabaseService>());
    });

    test('foodAnalysisServiceProvider exposes FoodAnalysisService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(foodAnalysisServiceProvider),
        isA<FoodAnalysisService>(),
      );
    });
  });
}
