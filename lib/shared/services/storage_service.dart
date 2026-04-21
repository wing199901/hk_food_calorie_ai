import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../models/body_metric.dart';
import '../models/quick_add_item.dart';
import 'supabase_service.dart';

class StorageService extends ChangeNotifier {
  StorageService({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? SupabaseService();

  static const _mealsKey = 'fitcalorie_meals';
  static const _targetKey = 'fitcalorie_target';
  static const _profileKey = 'fitcalorie_profile';
  static const _bodyHistoryKey = 'fitcalorie_body_history';
  static const _lastCheckInKey = 'fitcalorie_last_checkin';
  static const _shortcutsKey = 'fitcalorie_shortcuts';
  static const _quickAddKey = 'fitcalorie_quick_add_items';

  late SharedPreferences _prefs;
  final SupabaseService _supabase;

  /// Fire-and-forget Supabase write — silently ignored if not authenticated.
  void _syncAsync(Future<void> Function() fn) {
    if (!_supabase.isAuthenticated) return;
    fn().catchError((e) {
      if (kDebugMode) debugPrint('[StorageService] Supabase sync error: $e');
    });
  }

  /// Pull all data from Supabase and overwrite local storage.
  /// Call this once after the user signs in.
  Future<void> syncFromSupabase() async {
    if (!_supabase.isAuthenticated) return;
    try {
      final data = await _supabase.fetchAllUserData();

      // Meals (from meal_records table)
      final meals = data['meals'] as List<Meal>;
      if (meals.isNotEmpty) {
        await _prefs.setString(
          _mealsKey,
          jsonEncode(meals.map((e) => e.toJson()).toList()),
        );
      }

      // Body history
      final bodyHistory = data['bodyHistory'] as List<BodyMetric>;
      if (bodyHistory.isNotEmpty) {
        await _prefs.setString(
          _bodyHistoryKey,
          jsonEncode(bodyHistory.map((e) => e.toJson()).toList()),
        );
      }

      // Profile
      final profile = data['profile'] as UserProfile;
      if (profile.weight != null || profile.birthdate != null) {
        await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
        // Keep daily target aligned with profile-driven intake range.
        final intakeRange = calculateCalorieIntakeRange(profile);
        await _prefs.setString(_targetKey, intakeRange.max.toString());
      }

      // Calorie target is auto-calculated from profile via intake range
      // so we skip restoring it from Supabase here.

      // Last check-in date
      final lastCheckInDate = data['lastCheckInDate'] as String?;
      if (lastCheckInDate != null) {
        await _prefs.setString(_lastCheckInKey, lastCheckInDate);
      }

      // Quick add items
      final quickAddItems = data['quickAddItems'] as List<QuickAddItem>;
      if (quickAddItems.isNotEmpty) {
        await _prefs.setString(
          _quickAddKey,
          jsonEncode(quickAddItems.map((e) => e.toJson()).toList()),
        );
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[StorageService] syncFromSupabase error: $e');
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Clear ALL local data (used when signing into a real account).
  void clearAllLocalData() {
    _prefs.remove(_mealsKey);
    _prefs.remove(_targetKey);
    _prefs.remove(_profileKey);
    _prefs.remove(_bodyHistoryKey);
    _prefs.remove(_lastCheckInKey);
    _prefs.remove(_shortcutsKey);
    _prefs.remove(_quickAddKey);
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
    final dateStr = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.fromMillisecondsSinceEpoch(meal.timestamp));
    _syncAsync(() => _supabase.addMeal(meal, mealDate: dateStr));
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
      final dateStr = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.fromMillisecondsSinceEpoch(updatedMeal.timestamp));
      _syncAsync(() => _supabase.addMeal(updatedMeal, mealDate: dateStr));
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
    _syncAsync(() => _supabase.deleteMeal(id));
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
    _syncAsync(() => _supabase.saveCalorieTarget(target));
    notifyListeners();
  }

  ({int min, int max}) getDailyTargetRange() {
    final profile = getUserProfile();
    final currentWeight = profile.weight;
    final targetWeight = profile.targetWeight;

    if (currentWeight == null ||
        currentWeight <= 0 ||
        targetWeight == null ||
        targetWeight <= 0 ||
        inferGoalDirection(
              currentWeight: currentWeight,
              targetWeight: targetWeight,
            ) ==
            'maintain') {
      final target = getDailyTarget();
      return (min: target, max: target);
    }

    return calculateCalorieIntakeRange(profile);
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

      DateTime? lastUpdate;
      if (dayMeals.isNotEmpty) {
        final timestamps = dayMeals.map((m) => m.timestamp).toList()..sort();
        lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamps.last);
      }

      data.add({
        'fullDate': date,
        'dateStr': DateFormat('dd/MM').format(date),
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'target': getDailyTarget(),
        'lastUpdate': lastUpdate,
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

  /// Saves profile locally and syncs to Supabase.
  /// Awaiting this Future ensures the DB write completes.
  Future<void> setUserProfile(UserProfile profile) async {
    _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    final intakeRange = calculateCalorieIntakeRange(profile);
    _prefs.setString(_targetKey, intakeRange.max.toString());
    notifyListeners();
    if (!_supabase.isAuthenticated) return;
    await _supabase.saveProfile(profile, calorieTarget: intakeRange.max);
  }

  /// Returns intake range where min=max for maintain mode.
  static ({int min, int max}) calculateCalorieIntakeRange(UserProfile profile) {
    final currentTee = calculateTEE(profile);
    final currentWeight = profile.weight;
    final targetWeight = profile.targetWeight;

    if (currentWeight == null ||
        currentWeight <= 0 ||
        targetWeight == null ||
        targetWeight <= 0) {
      return (min: currentTee, max: currentTee);
    }

    final goalDirection = inferGoalDirection(
      currentWeight: currentWeight,
      targetWeight: targetWeight,
    );

    if (goalDirection == 'maintain') {
      return (min: currentTee, max: currentTee);
    }

    final goalActivityLevel = goalDirection == 'gain'
        ? _goalGainActivityLevel(profile.activityLevel)
        : (profile.activityLevel ?? 'moderate');

    final goalTee = calculateTEE(
      profile.copyWith(weight: targetWeight, activityLevel: goalActivityLevel),
    );

    return (
      min: math.min(currentTee, goalTee),
      max: math.max(currentTee, goalTee),
    );
  }

  /// Infers goal direction from current and target weight.
  /// Returns: lose | maintain | gain
  static String inferGoalDirection({
    required double currentWeight,
    required double targetWeight,
  }) {
    const maintainThresholdKg = 0.05;
    if (targetWeight < currentWeight - maintainThresholdKg) {
      return 'lose';
    }
    if (targetWeight > currentWeight + maintainThresholdKg) {
      return 'gain';
    }
    return 'maintain';
  }

  /// Returns weight (kg) at BMI 18.5 for the given height.
  static double? calculateHealthyBmiLowerWeightKg({required double? heightCm}) {
    if (heightCm == null || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return 18.5 * heightM * heightM;
  }

  /// Devine ideal body weight in kg based on height and gender.
  /// Formula base is at 5 ft (60 in), with 2.3 kg per inch difference.
  static double? calculateDevineIbwKg({
    required double? heightCm,
    required String? gender,
  }) {
    if (heightCm == null || heightCm <= 0) return null;

    final heightIn = heightCm / 2.54;
    final inchDiffFromFiveFeet = heightIn - 60;
    final maleIbw = 50 + (2.3 * inchDiffFromFiveFeet);
    final femaleIbw = 45.5 + (2.3 * inchDiffFromFiveFeet);

    return switch (gender) {
      'male' => maleIbw,
      'female' => femaleIbw,
      _ => (maleIbw + femaleIbw) / 2,
    };
  }

  /// Healthy range guide where lower bound is BMI 18.5 weight
  /// and upper bound is Devine IBW.
  static ({double minKg, double maxKg})? calculateHealthyWeightGuide({
    required double? heightCm,
    required String? gender,
  }) {
    final healthyLower = calculateHealthyBmiLowerWeightKg(heightCm: heightCm);
    final devineIbw = calculateDevineIbwKg(heightCm: heightCm, gender: gender);
    if (healthyLower == null || devineIbw == null) return null;

    return (
      minKg: math.min(healthyLower, devineIbw),
      maxKg: math.max(healthyLower, devineIbw),
    );
  }

  /// Gain target should not be based on ultra-low activity.
  /// We clamp to at least moderate so max TEE remains practical.
  static String _goalGainActivityLevel(String? activityLevel) {
    switch (activityLevel) {
      case 'moderate':
      case 'active':
      case 'very-active':
        return activityLevel!;
      case 'sedentary':
      case 'light':
      default:
        return 'moderate';
    }
  }

  /// Centralized TEE (Total Energy Expenditure) calculator.
  /// Uses FAO/WHO/UNU (2001) BMR equations × activity multiplier.
  static int calculateTEE(UserProfile profile) {
    final age = profile.age ?? 25;
    final weight = profile.weight ?? 70.0;
    final gender = profile.gender ?? 'male';
    final activityLevel = profile.activityLevel ?? 'moderate';

    double bmr;
    if (gender == 'male') {
      if (age < 30) {
        bmr = 15.3 * weight + 679;
      } else if (age < 60) {
        bmr = 11.6 * weight + 879;
      } else {
        bmr = 13.5 * weight + 487;
      }
    } else if (gender == 'female') {
      if (age < 30) {
        bmr = 14.7 * weight + 496;
      } else if (age < 60) {
        bmr = 8.7 * weight + 829;
      } else {
        bmr = 10.5 * weight + 596;
      }
    } else {
      // 'other': average of male + female
      double maleBmr, femaleBmr;
      if (age < 30) {
        maleBmr = 15.3 * weight + 679;
        femaleBmr = 14.7 * weight + 496;
      } else if (age < 60) {
        maleBmr = 11.6 * weight + 879;
        femaleBmr = 8.7 * weight + 829;
      } else {
        maleBmr = 13.5 * weight + 487;
        femaleBmr = 10.5 * weight + 596;
      }
      bmr = (maleBmr + femaleBmr) / 2;
    }

    const activityMultipliers = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very-active': 1.9,
    };
    return (bmr * (activityMultipliers[activityLevel] ?? 1.55)).round();
  }

  // ─── Body History ────────────────────────────────────────────

  static DateTime _metricSortDateTime(BodyMetric metric) {
    final createdAt = metric.createdAt != null
        ? DateTime.tryParse(metric.createdAt!)?.toUtc()
        : null;
    if (createdAt != null) return createdAt;

    final parsedDate = DateTime.tryParse(metric.date)?.toUtc();
    return parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static int _compareMetricsByHistoryTime(BodyMetric a, BodyMetric b) {
    final dateComparison = a.date.compareTo(b.date);
    if (dateComparison != 0) return dateComparison;
    return _metricSortDateTime(a).compareTo(_metricSortDateTime(b));
  }

  List<BodyMetric> getBodyHistory() {
    final data = _prefs.getString(_bodyHistoryKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    final history = list
        .map((e) => BodyMetric.fromJson(e as Map<String, dynamic>))
        .toList();
    history.sort(_compareMetricsByHistoryTime);
    return history;
  }

  void addBodyMetric(BodyMetric metric) {
    final history = getBodyHistory();
    final profile = getUserProfile();

    // Auto-compute health scores from profile + metric data
    final weight = metric.weight ?? profile.weight;
    final height = profile.height;
    final waist = metric.waistline ?? profile.waistline;

    double? bmi;
    double? whtr;
    int? tee;

    if (weight != null && height != null && height > 0) {
      bmi = double.parse(
        (weight / ((height / 100) * (height / 100))).toStringAsFixed(1),
      );
    }
    if (waist != null && height != null && height > 0) {
      whtr = double.parse((waist / height).toStringAsFixed(2));
    }
    tee = calculateTEE(profile.copyWith(weight: weight ?? profile.weight));

    final enriched = BodyMetric(
      date: metric.date,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      weight:
          metric.weight ??
          (history.isNotEmpty
              ? history
                    .lastWhere((m) => m.weight != null, orElse: () => metric)
                    .weight
              : null),
      waistline:
          metric.waistline ??
          (history.isNotEmpty
              ? history
                    .lastWhere((m) => m.waistline != null, orElse: () => metric)
                    .waistline
              : null),
      bmi: bmi,
      whtr: whtr,
      tee: tee,
    );

    history.add(enriched);
    history.sort(_compareMetricsByHistoryTime);
    _prefs.setString(
      _bodyHistoryKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
    _syncAsync(() => _supabase.saveBodyMetric(enriched));
    notifyListeners();
  }

  // ─── Last Check-In ───────────────────────────────────────────

  String? getLastCheckInDate() {
    return _prefs.getString(_lastCheckInKey);
  }

  void setLastCheckInDate(String dateStr) {
    _prefs.setString(_lastCheckInKey, dateStr);
    _syncAsync(() => _supabase.saveLastCheckInDate(dateStr));
  }

  // ─── Shortcuts ───────────────────────────────────────────────

  /// Returns pinned shortcut meals (max 12).
  List<Meal> getShortcuts() {
    final data = _prefs.getString(_shortcutsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => Meal.fromJson(e as Map<String, dynamic>)).toList();
  }

  void addShortcut(Meal meal) {
    final shortcuts = getShortcuts();
    // Deduplicate by name (case-insensitive)
    if (shortcuts.any((s) => s.name.toLowerCase() == meal.name.toLowerCase())) {
      return;
    }
    shortcuts.insert(0, meal);
    if (shortcuts.length > 12) shortcuts.removeLast();
    _prefs.setString(
      _shortcutsKey,
      jsonEncode(shortcuts.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  void removeShortcut(String id) {
    final shortcuts = getShortcuts();
    shortcuts.removeWhere((s) => s.id == id);
    _prefs.setString(
      _shortcutsKey,
      jsonEncode(shortcuts.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Returns recently logged meals deduplicated by name (most recent first).
  List<Meal> getRecentUniqueMeals({int limit = 30}) {
    final meals = getMeals().reversed.toList();
    final seen = <String>{};
    final result = <Meal>[];
    for (final m in meals) {
      final key = m.name.toLowerCase();
      if (seen.add(key)) {
        result.add(m);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  // ─── Quick Add Items ─────────────────────────────────────────

  /// Returns user's quick-add items. Seeds defaults if empty.
  List<QuickAddItem> getQuickAddItems() {
    final data = _prefs.getString(_quickAddKey);
    if (data == null) {
      // First time — seed defaults locally
      final defaults = QuickAddItem.defaults;
      _prefs.setString(
        _quickAddKey,
        jsonEncode(defaults.map((e) => e.toJson()).toList()),
      );
      return defaults;
    }
    final list = jsonDecode(data) as List;
    return list
        .map((e) => QuickAddItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void addQuickAddItem(QuickAddItem item) {
    final items = getQuickAddItems();
    // Deduplicate by name (case-insensitive)
    if (items.any((i) => i.name.toLowerCase() == item.name.toLowerCase())) {
      return;
    }
    items.add(item);
    _prefs.setString(
      _quickAddKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    _syncAsync(
      () => _supabase.addQuickAddItem(item, sortOrder: items.length - 1),
    );
    notifyListeners();
  }

  void removeQuickAddItem(String id) {
    final items = getQuickAddItems();
    items.removeWhere((i) => i.id == id);
    _prefs.setString(
      _quickAddKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    _syncAsync(() => _supabase.deleteQuickAddItem(id));
    notifyListeners();
  }
}
