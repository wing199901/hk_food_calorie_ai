import 'package:intl/intl.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/meal.dart';
import 'package:hk_food_calorie_ai/shared/models/quick_add_item.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';

import 'fake_supabase_service.dart';

class FakeStorageService extends StorageService {
  FakeStorageService({
    UserProfile? profile,
    List<Meal>? meals,
    List<BodyMetric>? bodyHistory,
    List<QuickAddItem>? quickAddItems,
    int dailyTarget = 2000,
    String? lastCheckInDate,
  }) : _profile = profile ?? UserProfile(),
       _meals = List<Meal>.from(meals ?? const []),
       _bodyHistory = List<BodyMetric>.from(bodyHistory ?? const []),
       _quickAddItems = List<QuickAddItem>.from(
         quickAddItems ?? QuickAddItem.defaults,
       ),
       _dailyTarget = dailyTarget,
       _lastCheckInDate = lastCheckInDate,
       super(supabaseService: FakeSupabaseService());

  UserProfile _profile;
  final List<Meal> _meals;
  final List<BodyMetric> _bodyHistory;
  final List<QuickAddItem> _quickAddItems;
  int _dailyTarget;
  String? _lastCheckInDate;

  @override
  List<Meal> getMeals() => List<Meal>.from(_meals);

  @override
  void saveMeal(Meal meal) {
    _meals.add(meal);
    notifyListeners();
  }

  @override
  void deleteMeal(String id) {
    _meals.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  @override
  List<Meal> getMealsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _meals.where((meal) {
      final mealDate = DateTime.fromMillisecondsSinceEpoch(meal.timestamp);
      return DateTime(mealDate.year, mealDate.month, mealDate.day) == target;
    }).toList();
  }

  @override
  Map<String, int> getStatsForDate(DateTime date) {
    final meals = getMealsForDate(date);
    final consumed = meals.fold<int>(0, (sum, meal) => sum + meal.calories);
    return {
      'consumed': consumed,
      'target': _dailyTarget,
      'remaining': _dailyTarget - consumed,
    };
  }

  @override
  int getDailyTarget() => _dailyTarget;

  @override
  void setDailyTarget(int target) {
    _dailyTarget = target;
    notifyListeners();
  }

  @override
  List<Map<String, dynamic>> getRangeData(DateTime startDate, int days) {
    final data = <Map<String, dynamic>>[];
    for (var i = 0; i < days; i += 1) {
      final date = DateTime(startDate.year, startDate.month, startDate.day + i);
      final dayMeals = getMealsForDate(date);
      final calories = dayMeals.fold<int>(
        0,
        (sum, meal) => sum + meal.calories,
      );
      final protein = dayMeals.fold<int>(
        0,
        (sum, meal) => sum + (meal.protein ?? 0),
      );
      final carbs = dayMeals.fold<int>(
        0,
        (sum, meal) => sum + (meal.carbs ?? 0),
      );
      final fat = dayMeals.fold<int>(0, (sum, meal) => sum + (meal.fat ?? 0));
      final lastUpdate = dayMeals.isEmpty
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              dayMeals
                  .map((meal) => meal.timestamp)
                  .reduce((a, b) => a > b ? a : b),
            );

      data.add({
        'fullDate': date,
        'dateStr': DateFormat('dd/MM').format(date),
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'target': _dailyTarget,
        'lastUpdate': lastUpdate,
      });
    }
    return data;
  }

  @override
  UserProfile getUserProfile() => _profile;

  @override
  Future<void> setUserProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
  }

  @override
  List<BodyMetric> getBodyHistory() => List<BodyMetric>.from(_bodyHistory);

  @override
  void addBodyMetric(BodyMetric metric) {
    final index = _bodyHistory.indexWhere((m) => m.date == metric.date);
    if (index == -1) {
      _bodyHistory.add(metric);
    } else {
      _bodyHistory[index] = metric;
    }
    _bodyHistory.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  @override
  String? getLastCheckInDate() => _lastCheckInDate;

  @override
  void setLastCheckInDate(String dateStr) {
    _lastCheckInDate = dateStr;
    notifyListeners();
  }

  @override
  List<QuickAddItem> getQuickAddItems() {
    return List<QuickAddItem>.from(_quickAddItems);
  }

  @override
  void addQuickAddItem(QuickAddItem item) {
    _quickAddItems.add(item);
    notifyListeners();
  }

  @override
  void removeQuickAddItem(String id) {
    _quickAddItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}
