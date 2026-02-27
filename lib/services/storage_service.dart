import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../models/body_metric.dart';

class StorageService extends ChangeNotifier {
  static const _mealsKey = 'fitcalorie_meals';
  static const _targetKey = 'fitcalorie_target';
  static const _profileKey = 'fitcalorie_profile';
  static const _demoInitializedKey = 'fitcalorie_demo_initialized';
  static const _bodyHistoryKey = 'fitcalorie_body_history';
  static const _lastCheckinKey = 'fitcalorie_last_checkin';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Demo Data ───────────────────────────────────────────────

  static List<Meal> _buildDemoMeals() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      Meal(
        id: 'demo-1',
        name: 'Breakfast Bowl with Berries',
        calories: 320,
        protein: 12,
        carbs: 54,
        fat: 8,
        timestamp: now - 7 * 60 * 60 * 1000,
        image:
            'https://images.unsplash.com/photo-1602682822546-09bc5623461e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-2',
        name: 'Grilled Chicken with Vegetables',
        calories: 420,
        protein: 38,
        carbs: 28,
        fat: 18,
        timestamp: now - 3 * 60 * 60 * 1000,
        image:
            'https://images.unsplash.com/photo-1682423187670-4817da9a1b23?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-3',
        name: 'Fresh Green Salad Bowl',
        calories: 280,
        protein: 15,
        carbs: 22,
        fat: 14,
        timestamp: now - 26 * 60 * 60 * 1000,
        image:
            'https://images.unsplash.com/photo-1649531794884-b8bb1de72e68?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-4',
        name: 'Berry Smoothie',
        calories: 240,
        protein: 8,
        carbs: 42,
        fat: 5,
        timestamp: now - 50 * 60 * 60 * 1000,
        image:
            'https://images.unsplash.com/photo-1588068403046-169c80c69938?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
    ];
  }

  static List<BodyMetric> _buildDemoBodyHistory() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    return [
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 30))),
        weight: 72.5,
        waistline: 85,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 20))),
        weight: 71.8,
        waistline: 84,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 10))),
        weight: 71.2,
        waistline: 83,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 5))),
        weight: 70.8,
        waistline: 82.5,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 1))),
        weight: 70.5,
        waistline: 82,
      ),
    ];
  }

  void initializeDemoData() {
    final bodyHistory = getBodyHistory();
    if (bodyHistory.isEmpty) {
      _prefs.setString(
        _bodyHistoryKey,
        jsonEncode(_buildDemoBodyHistory().map((e) => e.toJson()).toList()),
      );
      notifyListeners();
    }

    final initialized = _prefs.getString(_demoInitializedKey);
    if (initialized == null) {
      final meals = getMeals();
      if (meals.isEmpty) {
        _prefs.setString(
          _mealsKey,
          jsonEncode(_buildDemoMeals().map((e) => e.toJson()).toList()),
        );
      }
      _prefs.setString(_demoInitializedKey, 'true');
      notifyListeners();
    }
  }

  void clearDemoData() {
    _prefs.remove(_mealsKey);
    _prefs.remove(_demoInitializedKey);
    notifyListeners();
  }

  // ─── Meals ───────────────────────────────────────────────────

  List<Meal> getMeals() {
    final data = _prefs.getString(_mealsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => Meal.fromJson(e as Map<String, dynamic>)).toList();
  }

  void saveMeal(Meal meal) {
    final meals = getMeals();
    meals.add(meal);
    _prefs.setString(
      _mealsKey,
      jsonEncode(meals.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  void updateMeal(Meal updatedMeal) {
    final meals = getMeals();
    final index = meals.indexWhere((m) => m.id == updatedMeal.id);
    if (index != -1) {
      meals[index] = updatedMeal;
      _prefs.setString(
        _mealsKey,
        jsonEncode(meals.map((e) => e.toJson()).toList()),
      );
      notifyListeners();
    }
  }

  void deleteMeal(String id) {
    final meals = getMeals();
    meals.removeWhere((m) => m.id == id);
    _prefs.setString(
      _mealsKey,
      jsonEncode(meals.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  List<Meal> getMealsForDate(DateTime date) {
    final meals = getMeals();
    final target = DateTime(date.year, date.month, date.day);
    return meals.where((meal) {
      final mealDate = DateTime.fromMillisecondsSinceEpoch(meal.timestamp);
      return DateTime(mealDate.year, mealDate.month, mealDate.day) == target;
    }).toList();
  }

  // ─── Stats ───────────────────────────────────────────────────

  Map<String, int> getStatsForDate(DateTime date) {
    final meals = getMealsForDate(date);
    final consumed = meals.fold<int>(0, (sum, m) => sum + m.calories);
    final target = getDailyTarget();
    return {
      'consumed': consumed,
      'target': target,
      'remaining': target - consumed,
    };
  }

  // ─── Daily Target ────────────────────────────────────────────

  int getDailyTarget() {
    final target = _prefs.getString(_targetKey);
    return target != null ? int.parse(target) : 2000;
  }

  void setDailyTarget(int target) {
    _prefs.setString(_targetKey, target.toString());
    notifyListeners();
  }

  // ─── Weekly / Range Data ─────────────────────────────────────

  List<Map<String, dynamic>> getRangeData(DateTime startDate, int days) {
    final meals = getMeals();
    final data = <Map<String, dynamic>>[];

    for (int i = 0; i < days; i++) {
      final date = DateTime(startDate.year, startDate.month, startDate.day + i);
      final dayMeals = meals.where((meal) {
        final mealDate = DateTime.fromMillisecondsSinceEpoch(meal.timestamp);
        return DateTime(mealDate.year, mealDate.month, mealDate.day) == date;
      }).toList();

      final calories = dayMeals.fold<int>(0, (s, m) => s + m.calories);
      final protein = dayMeals.fold<int>(0, (s, m) => s + (m.protein ?? 0));
      final carbs = dayMeals.fold<int>(0, (s, m) => s + (m.carbs ?? 0));
      final fat = dayMeals.fold<int>(0, (s, m) => s + (m.fat ?? 0));

      data.add({
        'fullDate': date,
        'dateStr': DateFormat('dd/MM').format(date),
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'target': getDailyTarget(),
      });
    }
    return data;
  }

  // ─── User Profile ────────────────────────────────────────────

  UserProfile getUserProfile() {
    final data = _prefs.getString(_profileKey);
    if (data == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  void setUserProfile(UserProfile profile) {
    _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    notifyListeners();
  }

  // ─── Body History ────────────────────────────────────────────

  List<BodyMetric> getBodyHistory() {
    final data = _prefs.getString(_bodyHistoryKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list
        .map((e) => BodyMetric.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void addBodyMetric(BodyMetric metric) {
    final history = getBodyHistory();
    final index = history.indexWhere((m) => m.date == metric.date);
    if (index != -1) {
      history[index] = BodyMetric(
        date: metric.date,
        weight: metric.weight ?? history[index].weight,
        waistline: metric.waistline ?? history[index].waistline,
      );
    } else {
      history.add(metric);
    }
    history.sort((a, b) => a.date.compareTo(b.date));
    _prefs.setString(
      _bodyHistoryKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  // ─── Last Checkin ────────────────────────────────────────────

  String? getLastCheckinDate() {
    return _prefs.getString(_lastCheckinKey);
  }

  void setLastCheckinDate(String dateStr) {
    _prefs.setString(_lastCheckinKey, dateStr);
  }
}
