class UserProfile {
  final String? birthdate; // 'YYYY-MM-DD'
  final double? weight;
  final double? targetWeight; // Stored in kg
  final double? height;
  final double? waistline;
  final String? gender; // 'male' | 'female' | 'other'
  final String?
  activityLevel; // 'sedentary' | 'light' | 'moderate' | 'active' | 'very-active'
  final String? unitSystem; // 'metric' | 'imperial'

  UserProfile({
    this.birthdate,
    this.weight,
    this.targetWeight,
    this.height,
    this.waistline,
    this.gender,
    this.activityLevel,
    this.unitSystem,
  });

  /// Age computed from birthdate.
  int? get age {
    if (birthdate == null) return null;
    final bd = DateTime.tryParse(birthdate!);
    if (bd == null) return null;
    final now = DateTime.now();
    int years = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      years--;
    }
    return years;
  }

  Map<String, dynamic> toJson() => {
    'birthdate': birthdate,
    'weight': weight,
    'targetWeight': targetWeight,
    'height': height,
    'waistline': waistline,
    'gender': gender,
    'activityLevel': activityLevel,
    'unitSystem': unitSystem,
  };

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return (value as num).toDouble();
  }

  static double? _deriveLegacyTargetWeight(Map<String, dynamic> json) {
    final currentWeight = _toDouble(json['weight']);
    final legacyGoal = json['weightGoal'] as String?;
    final legacyDelta = _toDouble(json['goalWeightDelta']);

    if (currentWeight == null || currentWeight <= 0 || legacyGoal == null) {
      return null;
    }

    if (legacyGoal == 'maintain') {
      return currentWeight;
    }

    if (legacyDelta == null || legacyDelta <= 0) {
      return null;
    }

    final targetWeight = switch (legacyGoal) {
      'lose' => currentWeight - legacyDelta,
      'gain' => currentWeight + legacyDelta,
      _ => currentWeight,
    };

    return targetWeight > 0 ? targetWeight : null;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    birthdate: json['birthdate'] as String?,
    weight: _toDouble(json['weight']),
    targetWeight:
        _toDouble(json['targetWeight']) ?? _deriveLegacyTargetWeight(json),
    height: _toDouble(json['height']),
    waistline: _toDouble(json['waistline']),
    gender: json['gender'] as String?,
    activityLevel: json['activityLevel'] as String?,
    unitSystem: json['unitSystem'] as String?,
  );

  UserProfile copyWith({
    String? birthdate,
    double? weight,
    double? targetWeight,
    bool clearTargetWeight = false,
    double? height,
    double? waistline,
    String? gender,
    String? activityLevel,
    String? unitSystem,
  }) {
    return UserProfile(
      birthdate: birthdate ?? this.birthdate,
      weight: weight ?? this.weight,
      targetWeight: clearTargetWeight
          ? null
          : targetWeight ?? this.targetWeight,
      height: height ?? this.height,
      waistline: waistline ?? this.waistline,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }

  /// Whether the core account fields are filled (birthdate, gender, height, weight).
  bool get isProfileComplete =>
      birthdate != null && gender != null && height != null && weight != null;
}
