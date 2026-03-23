import '../models/user_profile.dart';

class HealthScoreUtils {
  static const double defaultWeightKg = 70.0;
  static const double defaultHeightCm = 175.0;
  static const double defaultWaistlineCm = 80.0;

  static double calculateBMI({
    required double? weightKg,
    required double? heightCm,
  }) {
    final w = weightKg ?? defaultWeightKg;
    final h = heightCm ?? defaultHeightCm;
    return double.parse((w / ((h / 100) * (h / 100))).toStringAsFixed(1));
  }

  static double calculateBMIFromProfile(UserProfile profile) {
    return calculateBMI(weightKg: profile.weight, heightCm: profile.height);
  }

  static double calculateWHtR({
    required double? waistlineCm,
    required double? heightCm,
  }) {
    final waist = waistlineCm ?? defaultWaistlineCm;
    final h = heightCm ?? defaultHeightCm;
    return double.parse((waist / h).toStringAsFixed(2));
  }

  static double calculateWHtRFromProfile(UserProfile profile) {
    return calculateWHtR(
      waistlineCm: profile.waistline,
      heightCm: profile.height,
    );
  }

  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  static String whtrCategory(double ratio) {
    if (ratio < 0.4) return 'Slim';
    if (ratio < 0.5) return 'Healthy';
    if (ratio < 0.6) return 'Overweight';
    return 'Obese';
  }

  static String activityLabel(String? level) {
    switch (level) {
      case 'sedentary':
        return 'Sedentary';
      case 'light':
        return 'Light';
      case 'moderate':
        return 'Moderate';
      case 'active':
        return 'Active';
      case 'very-active':
        return 'Very active';
      default:
        return 'Moderate';
    }
  }
}
