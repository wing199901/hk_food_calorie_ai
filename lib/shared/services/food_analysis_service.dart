import 'dart:math';

/// Domain-specific exception for AI meal analysis failures.
class FoodAnalysisException implements Exception {
  final String message;

  const FoodAnalysisException(this.message);

  @override
  String toString() => 'FoodAnalysisException: $message';
}

/// Simulates food photo analysis and returns normalized nutrition payload.
class FoodAnalysisService {
  FoodAnalysisService({
    Random? random,
    Duration simulatedLatency = const Duration(seconds: 2),
    double simulatedFailureRate = 0,
    List<Map<String, dynamic>>? foodDatabase,
  }) : _random = random ?? Random(),
       _simulatedLatency = simulatedLatency,
       _simulatedFailureRate = simulatedFailureRate,
       _foodDatabase = foodDatabase ?? _defaultFoodDatabase;

  final Random _random;
  final Duration _simulatedLatency;
  final double _simulatedFailureRate;
  final List<Map<String, dynamic>> _foodDatabase;

  static const List<String> _validImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.webp',
  ];

  static const List<Map<String, dynamic>> _defaultFoodDatabase = [
    {
      'name': 'BBQ Combo Rice',
      'calories': 750,
      'protein': 35,
      'carbs': 88,
      'fat': 28,
      'sugar': 6,
    },
    {
      'name': 'Pineapple Bun + Iced Milk Tea',
      'calories': 520,
      'protein': 8,
      'carbs': 62,
      'fat': 26,
      'sugar': 28,
    },
    {
      'name': 'Wonton Noodles',
      'calories': 380,
      'protein': 18,
      'carbs': 48,
      'fat': 12,
      'sugar': 4,
    },
    {
      'name': 'Char Siu Rice',
      'calories': 680,
      'protein': 32,
      'carbs': 85,
      'fat': 22,
      'sugar': 8,
    },
    {
      'name': 'Egg Tart',
      'calories': 220,
      'protein': 4,
      'carbs': 28,
      'fat': 10,
      'sugar': 12,
    },
    {
      'name': 'Dim Sum Platter (Har Gow, Siu Mai, Cheung Fun)',
      'calories': 580,
      'protein': 24,
      'carbs': 52,
      'fat': 28,
      'sugar': 6,
    },
    {
      'name': 'Pork Chop Bun',
      'calories': 450,
      'protein': 22,
      'carbs': 38,
      'fat': 24,
      'sugar': 4,
    },
    {
      'name': 'Fish Ball Noodles',
      'calories': 320,
      'protein': 16,
      'carbs': 42,
      'fat': 10,
      'sugar': 2,
    },
    {
      'name': 'Iced Lemon Tea',
      'calories': 120,
      'protein': 0,
      'carbs': 30,
      'fat': 0,
      'sugar': 28,
    },
    {
      'name': 'Claypot Rice',
      'calories': 620,
      'protein': 28,
      'carbs': 78,
      'fat': 22,
      'sugar': 6,
    },
  ];

  /// Analyzes an image path and returns one simulated food analysis record.
  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    _validateImagePath(imagePath);
    await Future.delayed(_simulatedLatency);

    if (_simulatedFailureRate > 0 &&
        _random.nextDouble() < _simulatedFailureRate) {
      throw const FoodAnalysisException(
        'Network error. Please check your connection and try again.',
      );
    }

    final selected = _foodDatabase[_random.nextInt(_foodDatabase.length)];
    return Map<String, dynamic>.from(selected);
  }

  void _validateImagePath(String imagePath) {
    final normalized = imagePath.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const FoodAnalysisException(
        'Invalid photo. Please select a valid image file.',
      );
    }

    final isSupported = _validImageExtensions.any(normalized.endsWith);
    if (!isSupported) {
      throw const FoodAnalysisException(
        'Invalid photo format. Please use JPG, PNG, HEIC, or WEBP.',
      );
    }
  }
}
