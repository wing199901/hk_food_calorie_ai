class Meal {
  final String id;
  final String name;
  final int calories;
  final int timestamp;
  final String? image;
  final int? protein;
  final int? carbs;
  final int? fat;
  final int? sugar;

  Meal({
    required this.id,
    required this.name,
    required this.calories,
    required this.timestamp,
    this.image,
    this.protein,
    this.carbs,
    this.fat,
    this.sugar,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'timestamp': timestamp,
    'image': image,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
  };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
    id: json['id'] as String,
    name: json['name'] as String,
    calories: (json['calories'] as num).toInt(),
    timestamp: (json['timestamp'] as num).toInt(),
    image: json['image'] as String?,
    protein: json['protein'] != null ? (json['protein'] as num).toInt() : null,
    carbs: json['carbs'] != null ? (json['carbs'] as num).toInt() : null,
    fat: json['fat'] != null ? (json['fat'] as num).toInt() : null,
    sugar: json['sugar'] != null ? (json['sugar'] as num).toInt() : null,
  );

  Meal copyWith({
    String? id,
    String? name,
    int? calories,
    int? timestamp,
    String? image,
    int? protein,
    int? carbs,
    int? fat,
    int? sugar,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      timestamp: timestamp ?? this.timestamp,
      image: image ?? this.image,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
    );
  }
}
