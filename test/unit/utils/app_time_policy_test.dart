import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/utils/app_time_policy.dart';

void main() {
  group('AppTimePolicy', () {
    test('nowUtcIsoString returns UTC timestamp', () {
      final raw = AppTimePolicy.nowUtcIsoString();
      final parsed = DateTime.parse(raw);

      expect(parsed.isUtc, isTrue);
      expect(raw.endsWith('Z'), isTrue);
    });

    test('normalizeTransportTimestamp converts offset time to UTC ISO', () {
      final normalized = AppTimePolicy.normalizeTransportTimestamp(
        '2026-04-23T16:30:00+08:00',
      );

      expect(normalized, DateTime.utc(2026, 4, 23, 8, 30).toIso8601String());
    });

    test('parseTransportTimestampToLocal round-trips with UTC', () {
      final local = AppTimePolicy.parseTransportTimestampToLocal(
        '2026-04-23T00:30:00Z',
      );
      final utc = AppTimePolicy.parseTransportTimestampToUtc(
        '2026-04-23T00:30:00Z',
      );

      expect(local, isNotNull);
      expect(utc, isNotNull);
      expect(local!.toUtc(), utc);
    });

    test('parseDateKeyLocal parses YYYY-MM-DD as local date key', () {
      final parsed = AppTimePolicy.parseDateKeyLocal('2026-04-23');

      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 4);
      expect(parsed.day, 23);
      expect(parsed.hour, 0);
      expect(parsed.minute, 0);
    });

    test('formatDateKeyLocal returns YYYY-MM-DD using local calendar date', () {
      final key = AppTimePolicy.formatDateKeyLocal(
        DateTime(2026, 4, 23, 12, 1),
      );

      expect(key, '2026-04-23');
    });
  });
}
