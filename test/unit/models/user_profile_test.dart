import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

void main() {
  group('UserProfile', () {
    test('computes age from valid birthdate', () {
      final now = DateTime.now();
      final birthdate = DateTime(now.year - 25, now.month, now.day);
      final profile = UserProfile(birthdate: _isoDate(birthdate));

      expect(profile.age, 25);
    });

    test('returns null age for invalid birthdate', () {
      final profile = UserProfile(birthdate: 'not-a-date');
      expect(profile.age, isNull);
    });

    test('serializes and deserializes with fromJson/toJson', () {
      final profile = UserProfile(
        birthdate: '1995-06-12',
        weight: 71.2,
        targetWeight: 65.0,
        height: 173.4,
        waistline: 82.0,
        gender: 'female',
        activityLevel: 'active',
        unitSystem: 'metric',
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.birthdate, '1995-06-12');
      expect(restored.weight, 71.2);
      expect(restored.targetWeight, 65.0);
      expect(restored.height, 173.4);
      expect(restored.waistline, 82.0);
      expect(restored.gender, 'female');
      expect(restored.activityLevel, 'active');
      expect(restored.unitSystem, 'metric');
    });

    test('copyWith updates selected fields only', () {
      final base = UserProfile(
        birthdate: '1990-01-01',
        weight: 70,
        targetWeight: 70,
        height: 175,
        gender: 'male',
      );

      final updated = base.copyWith(
        weight: 72.5,
        targetWeight: 76.0,
        unitSystem: 'imperial',
      );

      expect(updated.birthdate, '1990-01-01');
      expect(updated.weight, 72.5);
      expect(updated.targetWeight, 76.0);
      expect(updated.height, 175);
      expect(updated.gender, 'male');
      expect(updated.unitSystem, 'imperial');
    });

    test('isProfileComplete is true only when required fields are present', () {
      final incomplete = UserProfile(gender: 'male', weight: 70, height: 175);
      final complete = UserProfile(
        birthdate: '1990-01-01',
        gender: 'male',
        weight: 70,
        height: 175,
      );

      expect(incomplete.isProfileComplete, isFalse);
      expect(complete.isProfileComplete, isTrue);
    });
  });
}
