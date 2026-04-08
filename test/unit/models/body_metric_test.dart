import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';

void main() {
  group('BodyMetric', () {
    test('toJson and fromJson preserve values', () {
      final metric = BodyMetric(
        date: '2026-04-08',
        weight: 70.5,
        waistline: 82.2,
        bmi: 23.0,
        whtr: 0.47,
        tee: 2100,
        createdAt: '2026-04-08T10:00:00Z',
      );

      final restored = BodyMetric.fromJson(metric.toJson());

      expect(restored.date, '2026-04-08');
      expect(restored.weight, 70.5);
      expect(restored.waistline, 82.2);
      expect(restored.bmi, 23.0);
      expect(restored.whtr, 0.47);
      expect(restored.tee, 2100);
      expect(restored.createdAt, '2026-04-08T10:00:00Z');
    });

    test('copyWith updates selected fields only', () {
      final metric = BodyMetric(date: '2026-04-08', weight: 68, tee: 2000);
      final updated = metric.copyWith(weight: 69.2, tee: 2050);

      expect(updated.date, '2026-04-08');
      expect(updated.weight, 69.2);
      expect(updated.tee, 2050);
    });
  });
}
