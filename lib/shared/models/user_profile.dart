class UserProfile {
  final String? birthdate; // 'YYYY-MM-DD'
  final double? weight;
  final String? weightGoal; // 'lose' | 'maintain' | 'gain'
  final double? goalWeightDelta; // Stored in kg
  final double? height;
  final double? waistline;
  final String? gender; // 'male' | 'female' | 'other'
  final String?
  activityLevel; // 'sedentary' | 'light' | 'moderate' | 'active' | 'very-active'
  final String? unitSystem; // 'metric' | 'imperial'

  UserProfile({
    this.birthdate,
    this.weight,
    this.weightGoal,
    this.goalWeightDelta,
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
    'weightGoal': weightGoal,
    'goalWeightDelta': goalWeightDelta,
    'height': height,
    'waistline': waistline,
    'gender': gender,
    'activityLevel': activityLevel,
    'unitSystem': unitSystem,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    birthdate: json['birthdate'] as String?,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    weightGoal: json['weightGoal'] as String?,
    goalWeightDelta: json['goalWeightDelta'] != null
        ? (json['goalWeightDelta'] as num).toDouble()
        : null,
    height: json['height'] != null ? (json['height'] as num).toDouble() : null,
    waistline: json['waistline'] != null
        ? (json['waistline'] as num).toDouble()
        : null,
    gender: json['gender'] as String?,
    activityLevel: json['activityLevel'] as String?,
    unitSystem: json['unitSystem'] as String?,
  );

  UserProfile copyWith({
    String? birthdate,
    double? weight,
    String? weightGoal,
    double? goalWeightDelta,
    bool clearGoalWeightDelta = false,
    double? height,
    double? waistline,
    String? gender,
    String? activityLevel,
    String? unitSystem,
  }) {
    return UserProfile(
      birthdate: birthdate ?? this.birthdate,
      weight: weight ?? this.weight,
      weightGoal: weightGoal ?? this.weightGoal,
      goalWeightDelta: clearGoalWeightDelta
          ? null
          : goalWeightDelta ?? this.goalWeightDelta,
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
