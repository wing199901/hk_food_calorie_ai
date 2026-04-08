import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/food_analysis_service.dart';

/// Global provider for [FoodAnalysisService] (meal photo analysis).
final foodAnalysisServiceProvider = Provider<FoodAnalysisService>((ref) {
  return FoodAnalysisService();
});
