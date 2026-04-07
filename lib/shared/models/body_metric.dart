class BodyMetric {
  final String date; // YYYY-MM-DD
  final double? weight;
  final double? waistline;
  final double? bmi;
  final double? whtr;
  final int? tee;
  final String? createdAt; // ISO8601 string for real update time

  BodyMetric({
    required this.date,
    this.weight,
    this.waistline,
    this.bmi,
    this.whtr,
    this.tee,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'weight': weight,
    'waistline': waistline,
    'bmi': bmi,
    'whtr': whtr,
    'tee': tee,
    'created_at': createdAt,
  };

  factory BodyMetric.fromJson(Map<String, dynamic> json) => BodyMetric(
    date: json['date'] as String,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    waistline: json['waistline'] != null
        ? (json['waistline'] as num).toDouble()
        : null,
    bmi: json['bmi'] != null ? (json['bmi'] as num).toDouble() : null,
    whtr: json['whtr'] != null ? (json['whtr'] as num).toDouble() : null,
    tee: json['tee'] != null ? (json['tee'] as num).toInt() : null,
    createdAt: json['created_at'] as String?,
  );

  BodyMetric copyWith({
    String? date,
    double? weight,
    double? waistline,
    double? bmi,
    double? whtr,
    int? tee,
    String? createdAt,
  }) {
    return BodyMetric(
      date: date ?? this.date,
      weight: weight ?? this.weight,
      waistline: waistline ?? this.waistline,
      bmi: bmi ?? this.bmi,
      whtr: whtr ?? this.whtr,
      tee: tee ?? this.tee,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
