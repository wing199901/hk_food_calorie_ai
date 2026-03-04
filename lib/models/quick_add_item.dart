class QuickAddItem {
  final String id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int sugar;
  final String icon;

  QuickAddItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'icon': icon,
  };

  factory QuickAddItem.fromJson(Map<String, dynamic> json) => QuickAddItem(
    id: json['id'] as String,
    name: json['name'] as String,
    calories: (json['calories'] as num).toInt(),
    protein: (json['protein'] as num?)?.toInt() ?? 0,
    carbs: (json['carbs'] as num?)?.toInt() ?? 0,
    fat: (json['fat'] as num?)?.toInt() ?? 0,
    sugar: (json['sugar'] as num?)?.toInt() ?? 0,
    icon: (json['icon'] as String?) ?? '🍽️',
  );

  QuickAddItem copyWith({
    String? id,
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? sugar,
    String? icon,
  }) {
    return QuickAddItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
      icon: icon ?? this.icon,
    );
  }

  /// Default quick add items seeded for new users.
  static List<QuickAddItem> get defaults => [
    QuickAddItem(
      id: 'default-white-rice',
      name: 'White Rice',
      calories: 230,
      protein: 4,
      carbs: 50,
      fat: 0,
      sugar: 0,
      icon: '🍚',
    ),
    QuickAddItem(
      id: 'default-egg',
      name: 'Egg',
      calories: 78,
      protein: 6,
      carbs: 0,
      fat: 5,
      sugar: 0,
      icon: '🥚',
    ),
    QuickAddItem(
      id: 'default-banana',
      name: 'Banana',
      calories: 105,
      protein: 1,
      carbs: 27,
      fat: 0,
      sugar: 14,
      icon: '🍌',
    ),
    QuickAddItem(
      id: 'default-toast',
      name: 'Toast (2 slices)',
      calories: 160,
      protein: 6,
      carbs: 30,
      fat: 2,
      sugar: 4,
      icon: '🍞',
    ),
    QuickAddItem(
      id: 'default-coffee',
      name: 'Coffee with Milk',
      calories: 120,
      protein: 4,
      carbs: 10,
      fat: 6,
      sugar: 8,
      icon: '☕',
    ),
    QuickAddItem(
      id: 'default-chicken-breast',
      name: 'Chicken Breast',
      calories: 165,
      protein: 31,
      carbs: 0,
      fat: 4,
      sugar: 0,
      icon: '🍗',
    ),
    QuickAddItem(
      id: 'default-apple',
      name: 'Apple',
      calories: 95,
      protein: 0,
      carbs: 25,
      fat: 0,
      sugar: 19,
      icon: '🍎',
    ),
    QuickAddItem(
      id: 'default-greek-yogurt',
      name: 'Greek Yogurt',
      calories: 100,
      protein: 10,
      carbs: 6,
      fat: 3,
      sugar: 5,
      icon: '🥛',
    ),
  ];
}
