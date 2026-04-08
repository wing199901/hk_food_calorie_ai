import 'package:hk_food_calorie_ai/shared/services/food_analysis_service.dart';

class FakeFoodAnalysisService extends FoodAnalysisService {
  FakeFoodAnalysisService({
    this.shouldThrowNetworkError = false,
    Map<String, dynamic>? analysisResult,
  }) : _analysisResult = analysisResult ?? _defaultAnalysisResult;

  bool shouldThrowNetworkError;
  int analyzeCallCount = 0;
  final Map<String, dynamic> _analysisResult;

  static const Map<String, dynamic> _defaultAnalysisResult = {
    'name': 'Test Chicken Rice',
    'calories': 600,
    'protein': 30,
    'carbs': 70,
    'fat': 20,
    'sugar': 5,
  };

  @override
  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    analyzeCallCount += 1;

    if (imagePath.endsWith('.txt')) {
      throw const FoodAnalysisException(
        'Invalid photo format. Please use JPG, PNG, HEIC, or WEBP.',
      );
    }

    if (shouldThrowNetworkError) {
      throw const FoodAnalysisException(
        'Network error. Please check your connection and try again.',
      );
    }

    return Map<String, dynamic>.from(_analysisResult);
  }
}
