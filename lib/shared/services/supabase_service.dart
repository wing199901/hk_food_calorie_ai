import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../models/body_metric.dart';
import '../models/quick_add_item.dart';
import '../../env/env.dart';
import '../../core/utils/app_time_policy.dart';
import '../utils/storage_url_utils.dart';

class SupabaseService extends ChangeNotifier {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _mealImageBucket = 'meal-images';
  static const _mealImageSignedUrlExpiresInSeconds = 60 * 60 * 24 * 7;

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Call once in main() before runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Stream that emits whenever the auth state changes (login / logout).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) => _client.auth.signUp(email: email, password: password);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) => _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  // ─── Activity-level int ↔ string mapping ─────────────────────────────────

  static const _activityLevels = [
    'sedentary', // 0
    'light', // 1
    'moderate', // 2
    'active', // 3
    'very-active', // 4
  ];

  static int _activityToInt(String? level) {
    if (level == null) return 2; // default: moderate
    final idx = _activityLevels.indexOf(level);
    return idx >= 0 ? idx : 2;
  }

  static String? _activityFromInt(dynamic val) {
    if (val == null) return null;
    final idx = (val as num).toInt();
    return idx >= 0 && idx < _activityLevels.length
        ? _activityLevels[idx]
        : null;
  }

  // ─── User Profile ──────────────────────────────────────────────────────────

  Future<UserProfile> fetchProfile() async {
    final uid = _requireUid();
    final data = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (data == null) return UserProfile();

    final currentWeight = data['weight'] != null
        ? (data['weight'] as num).toDouble()
        : null;
    final targetWeight = data['target_weight'] != null
        ? (data['target_weight'] as num).toDouble()
        : null;
    final legacyGoal = data['weight_goal'] as String?;
    final legacyDelta = data['goal_weight_delta'] != null
        ? (data['goal_weight_delta'] as num).toDouble()
        : null;

    final fallbackTargetWeight = switch (legacyGoal) {
      'lose' when currentWeight != null && legacyDelta != null =>
        currentWeight - legacyDelta,
      'gain' when currentWeight != null && legacyDelta != null =>
        currentWeight + legacyDelta,
      'maintain' when currentWeight != null => currentWeight,
      _ => null,
    };

    return UserProfile(
      birthdate: data['birthdate'] as String?,
      weight: currentWeight,
      targetWeight: targetWeight ?? fallbackTargetWeight,
      height: data['height'] != null
          ? (data['height'] as num).toDouble()
          : null,
      waistline: data['waistline'] != null
          ? (data['waistline'] as num).toDouble()
          : null,
      gender: data['gender'] as String?,
      activityLevel: _activityFromInt(data['activity_level']),
      unitSystem: data['unit_system'] as String?,
    );
  }

  Future<void> saveProfile(UserProfile profile, {int? calorieTarget}) async {
    final uid = _requireUid();
    final tee = calorieTarget;
    await _client.from('user_profiles').upsert({
      'user_id': uid,
      if (profile.birthdate != null) 'birthdate': profile.birthdate,
      if (profile.weight != null) 'weight': profile.weight,
      if (profile.targetWeight != null) 'target_weight': profile.targetWeight,
      if (profile.height != null) 'height': profile.height,
      if (profile.waistline != null) 'waistline': profile.waistline,
      if (profile.gender != null) 'gender': profile.gender,
      'activity_level': _activityToInt(profile.activityLevel),
      if (profile.unitSystem != null) 'unit_system': profile.unitSystem,
      if (tee != null) 'calorie_target': tee,
    });
  }

  // ─── Calorie Target ────────────────────────────────────────────────────────

  Future<int?> fetchCalorieTarget() async {
    final uid = _requireUid();
    final data = await _client
        .from('user_profiles')
        .select('calorie_target')
        .eq('user_id', uid)
        .maybeSingle();
    return data?['calorie_target'] as int?;
  }

  Future<void> saveCalorieTarget(int target) async {
    final uid = _requireUid();
    await _client.from('user_profiles').upsert({
      'user_id': uid,
      'calorie_target': target,
    });
  }

  // ─── Last Check-in Date ────────────────────────────────────────────────────

  Future<String?> fetchLastCheckInDate() async {
    final uid = _requireUid();
    final data = await _client
        .from('user_profiles')
        .select('last_check_in_date')
        .eq('user_id', uid)
        .maybeSingle();
    return data?['last_check_in_date'] as String?;
  }

  Future<void> saveLastCheckInDate(String date) async {
    final uid = _requireUid();
    await _client.from('user_profiles').upsert({
      'user_id': uid,
      'last_check_in_date': date,
    });
  }

  // ─── Meals (stored in meal_records table) ──────────────────────────────────

  /// Fetch all meals from meal_records, optionally filtered by meal date.
  Future<List<Meal>> fetchMeals({String? mealDate}) async {
    final uid = _requireUid();
    var query = _client
        .from('meal_records')
        .select()
        .eq('user_id', uid)
        .isFilter('deleted_at', null);
    if (mealDate != null) {
      query = query.eq('meal_date', mealDate);
    }
    final data = await query.order('created_at', ascending: false);
    final list = <Meal>[];
    for (final row in data as List<dynamic>) {
      final rec = row as Map<String, dynamic>;
      final imagePath = rec['image_path'] as String?;
      final imageUrl = await _resolveMealImageUrl(rec);
      final items = rec['items'] as List<dynamic>? ?? [];
      if (items.length == 1) {
        // Single-item record → map directly to a Meal
        final item = items[0] as Map<String, dynamic>;
        list.add(
          Meal(
            id: rec['id'] as String,
            name: (item['name'] ?? '') as String,
            calories: (rec['total_calories'] as num?)?.toInt() ?? 0,
            protein: (rec['total_protein'] as num?)?.toInt(),
            carbs: (rec['total_carbs'] as num?)?.toInt(),
            fat: (rec['total_fat'] as num?)?.toInt(),
            timestamp: (rec['created_at'] != null)
                ? DateTime.parse(
                    rec['created_at'] as String,
                  ).millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch,
            image: imageUrl,
            imagePath: imagePath,
          ),
        );
      } else {
        // Multi-item record (AI analysis) → one Meal per record using totals
        final firstName = items.isNotEmpty
            ? (items[0] as Map<String, dynamic>)['name'] ?? 'AI Scanned Meal'
            : 'AI Scanned Meal';
        list.add(
          Meal(
            id: rec['id'] as String,
            name: items.length > 1
                ? '$firstName + ${items.length - 1} more'
                : firstName as String,
            calories: (rec['total_calories'] as num?)?.toInt() ?? 0,
            protein: (rec['total_protein'] as num?)?.toInt(),
            carbs: (rec['total_carbs'] as num?)?.toInt(),
            fat: (rec['total_fat'] as num?)?.toInt(),
            timestamp: (rec['created_at'] != null)
                ? DateTime.parse(
                    rec['created_at'] as String,
                  ).millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch,
            image: imageUrl,
            imagePath: imagePath,
          ),
        );
      }
    }
    return list;
  }

  /// Save a Meal as a single-item meal_record.
  Future<void> addMeal(Meal meal, {required String mealDate}) async {
    final uid = _requireUid();
    await _client.from('meal_records').upsert({
      'id': meal.id,
      'user_id': uid,
      'meal_date': mealDate,
      'items': [
        {
          'name': meal.name,
          'calories': meal.calories,
          'protein': meal.protein ?? 0,
          'carbs': meal.carbs ?? 0,
          'fat': meal.fat ?? 0,
          'portion': '1 serving',
          'confidence': 1.0,
        },
      ],
      'total_calories': meal.calories,
      'total_protein': meal.protein ?? 0,
      'total_carbs': meal.carbs ?? 0,
      'total_fat': meal.fat ?? 0,
      'image_url': meal.image,
      'image_path': meal.imagePath,
    });
  }

  /// Soft-delete a meal (meal record).
  Future<void> deleteMeal(String mealId) async {
    await _client
        .from('meal_records')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', mealId);
  }

  /// Persist user confirmation feedback for one AI analysis result.
  Future<void> saveAiMealAnalysisFeedback({
    required String analysisId,
    required String mealRecordId,
    required bool isCorrect,
    required Map<String, dynamic> finalResult,
  }) async {
    await _client.functions.invoke(
      'submit-analysis-feedback',
      body: {
        'analysis_id': analysisId,
        'meal_record_id': mealRecordId,
        'is_correct': isCorrect,
        'final_result': finalResult,
      },
    );
  }

  // ─── Body Metrics ──────────────────────────────────────────────────────────

  Future<List<BodyMetric>> fetchBodyHistory() async {
    final uid = _requireUid();
    final data = await _client
        .from('body_metrics')
        .select()
        .eq('user_id', uid)
        .order('date', ascending: true)
        .order('created_at', ascending: true);
    return (data as List<dynamic>)
        .map((e) => BodyMetric.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBodyMetric(BodyMetric metric) async {
    final uid = _requireUid();
    final normalizedCreatedAt = AppTimePolicy.normalizeTransportTimestamp(
      metric.createdAt,
    );

    await _client.from('body_metrics').insert({
      'user_id': uid,
      'date': metric.date,
      'weight': metric.weight,
      'waistline': metric.waistline,
      'bmi': metric.bmi,
      'whtr': metric.whtr,
      'tee': metric.tee,
      if (normalizedCreatedAt != null) 'created_at': normalizedCreatedAt,
    });
  }

  // ─── Quick Add Items ───────────────────────────────────────────────────────

  /// Fetch all quick-add items for the current user, ordered by sort_order.
  Future<List<QuickAddItem>> fetchQuickAddItems() async {
    final uid = _requireUid();
    final data = await _client
        .from('quick_add_items')
        .select()
        .eq('user_id', uid)
        .order('sort_order', ascending: true);
    return (data as List<dynamic>)
        .map((e) => QuickAddItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Insert a new quick-add item.
  Future<void> addQuickAddItem(QuickAddItem item, {int sortOrder = 0}) async {
    final uid = _requireUid();
    await _client.from('quick_add_items').insert({
      'id': item.id,
      'user_id': uid,
      'name': item.name,
      'calories': item.calories,
      'protein': item.protein,
      'carbs': item.carbs,
      'fat': item.fat,
      'sugar': item.sugar,
      'icon': item.icon,
      'sort_order': sortOrder,
    });
  }

  /// Delete a quick-add item.
  Future<void> deleteQuickAddItem(String itemId) async {
    final uid = _requireUid();
    await _client
        .from('quick_add_items')
        .delete()
        .eq('user_id', uid)
        .eq('id', itemId);
  }

  // ─── Sync All ──────────────────────────────────────────────────────────────

  /// Pull all user data from Supabase in one batch.
  Future<Map<String, dynamic>> fetchAllUserData() async {
    final results = await Future.wait([
      fetchProfile(),
      fetchCalorieTarget(),
      fetchLastCheckInDate(),
      fetchMeals(),
      fetchBodyHistory(),
      fetchQuickAddItems(),
    ]);
    return {
      'profile': results[0] as UserProfile,
      'calorieTarget': results[1] as int?,
      'lastCheckInDate': results[2] as String?,
      'meals': results[3] as List<Meal>,
      'bodyHistory': results[4] as List<BodyMetric>,
      'quickAddItems': results[5] as List<QuickAddItem>,
    };
  }

  Future<String?> _resolveMealImageUrl(Map<String, dynamic> record) async {
    final imagePath = record['image_path'] as String?;
    final fallbackImageUrl = record['image_url'] as String?;

    if (imagePath == null || imagePath.isEmpty) {
      if (fallbackImageUrl == null || fallbackImageUrl.isEmpty) {
        return fallbackImageUrl;
      }

      return _normalizeStorageUrl(fallbackImageUrl);
    }

    try {
      final signedUrl = await _client.storage
          .from(_mealImageBucket)
          .createSignedUrl(imagePath, _mealImageSignedUrlExpiresInSeconds);

      return _normalizeStorageUrl(signedUrl);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[SupabaseService] createSignedUrl failed: $error');
      }
      if (fallbackImageUrl == null || fallbackImageUrl.isEmpty) {
        return fallbackImageUrl;
      }

      return _normalizeStorageUrl(fallbackImageUrl);
    }
  }

  String _normalizeStorageUrl(String url) {
    return normalizeStorageUrl(url, baseUrl: Env.supabaseUrl);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _requireUid() {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('SupabaseService: user is not logged in');
    return uid;
  }
}
