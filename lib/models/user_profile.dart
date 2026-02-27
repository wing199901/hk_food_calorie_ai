class UserProfile {
  final int? age;
  final double? weight;
  final double? height;
  final double? waistline;
  final String? gender; // 'male' | 'female' | 'other'
  final String?
  activityLevel; // 'sedentary' | 'light' | 'moderate' | 'active' | 'very-active'

  UserProfile({
    this.age,
    this.weight,
    this.height,
    this.waistline,
    this.gender,
    this.activityLevel,
  });

  Map<String, dynamic> toJson() => {
    'age': age,
    'weight': weight,
    'height': height,
    'waistline': waistline,
    'gender': gender,
    'activityLevel': activityLevel,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    age: json['age'] != null ? (json['age'] as num).toInt() : null,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    height: json['height'] != null ? (json['height'] as num).toDouble() : null,
    waistline: json['waistline'] != null
        ? (json['waistline'] as num).toDouble()
        : null,
    gender: json['gender'] as String?,
    activityLevel: json['activityLevel'] as String?,
  );

  UserProfile copyWith({
    int? age,
    double? weight,
    double? height,
    double? waistline,
    String? gender,
    String? activityLevel,
  }) {
    return UserProfile(
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      waistline: waistline ?? this.waistline,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }
}
