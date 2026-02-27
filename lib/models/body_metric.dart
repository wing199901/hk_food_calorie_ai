class BodyMetric {
  final String date; // YYYY-MM-DD
  final double? weight;
  final double? waistline;

  BodyMetric({required this.date, this.weight, this.waistline});

  Map<String, dynamic> toJson() => {
    'date': date,
    'weight': weight,
    'waistline': waistline,
  };

  factory BodyMetric.fromJson(Map<String, dynamic> json) => BodyMetric(
    date: json['date'] as String,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    waistline: json['waistline'] != null
        ? (json['waistline'] as num).toDouble()
        : null,
  );

  BodyMetric copyWith({String? date, double? weight, double? waistline}) {
    return BodyMetric(
      date: date ?? this.date,
      weight: weight ?? this.weight,
      waistline: waistline ?? this.waistline,
    );
  }
}
