import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../models/meal.dart';
import '../theme/app_theme.dart';

class CameraPage extends StatefulWidget {
  final Function(String) onNavigate;
  final StorageService storage;

  const CameraPage({
    super.key,
    required this.onNavigate,
    required this.storage,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String? _selectedImage;
  bool _analyzing = false;
  Map<String, dynamic>? _result;

  static const _foodDatabase = [
    {
      'name': 'Grilled Chicken Salad',
      'calories': 350,
      'protein': 35,
      'carbs': 15,
      'fat': 18,
    },
    {
      'name': 'Pasta Carbonara',
      'calories': 580,
      'protein': 22,
      'carbs': 65,
      'fat': 28,
    },
    {
      'name': 'Salmon with Vegetables',
      'calories': 420,
      'protein': 38,
      'carbs': 12,
      'fat': 24,
    },
    {
      'name': 'Burger with Fries',
      'calories': 850,
      'protein': 32,
      'carbs': 78,
      'fat': 45,
    },
    {
      'name': 'Caesar Salad',
      'calories': 320,
      'protein': 18,
      'carbs': 12,
      'fat': 22,
    },
    {
      'name': 'Sushi Roll Set',
      'calories': 450,
      'protein': 20,
      'carbs': 68,
      'fat': 8,
    },
    {
      'name': 'Pizza Slice',
      'calories': 285,
      'protein': 12,
      'carbs': 36,
      'fat': 10,
    },
    {
      'name': 'Fruit Bowl',
      'calories': 150,
      'protein': 2,
      'carbs': 38,
      'fat': 1,
    },
    {
      'name': 'Protein Smoothie',
      'calories': 280,
      'protein': 25,
      'carbs': 32,
      'fat': 6,
    },
    {
      'name': 'Oatmeal with Berries',
      'calories': 320,
      'protein': 12,
      'carbs': 54,
      'fat': 8,
    },
  ];

  static const _preconfiguredItems = [
    {
      'name': 'Bowl of Rice',
      'calories': 200,
      'protein': 4,
      'carbs': 45,
      'fat': 0,
      'icon': '🍚',
    },
    {
      'name': 'Apple',
      'calories': 95,
      'protein': 0,
      'carbs': 25,
      'fat': 0,
      'icon': '🍎',
    },
    {
      'name': 'Banana',
      'calories': 105,
      'protein': 1,
      'carbs': 27,
      'fat': 0,
      'icon': '🍌',
    },
    {
      'name': 'Boiled Egg',
      'calories': 78,
      'protein': 6,
      'carbs': 0,
      'fat': 5,
      'icon': '🥚',
    },
    {
      'name': 'Slice of Bread',
      'calories': 80,
      'protein': 3,
      'carbs': 15,
      'fat': 1,
      'icon': '🍞',
    },
    {
      'name': 'Coffee (Black)',
      'calories': 2,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'icon': '☕',
    },
    {
      'name': 'Black Tea',
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'icon': '🍵',
    },
    {
      'name': 'Instant Noodle',
      'calories': 380,
      'protein': 8,
      'carbs': 54,
      'fat': 14,
      'icon': '🍜',
    },
  ];

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1080);
    if (picked != null) {
      setState(() {
        _selectedImage = picked.path;
      });
      _analyzeImage(picked.path);
    }
  }

  void _analyzeImage(String imagePath) {
    setState(() => _analyzing = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final randomFood = _foodDatabase[Random().nextInt(_foodDatabase.length)];
      setState(() {
        _result = Map<String, dynamic>.from(randomFood);
        _analyzing = false;
      });
    });
  }

  void _handleQuickAdd(Map<String, dynamic> item) {
    setState(() {
      _selectedImage = null;
      _result = {
        'name': item['name'],
        'calories': item['calories'],
        'protein': item['protein'],
        'carbs': item['carbs'],
        'fat': item['fat'],
      };
    });
  }

  void _handleSave() {
    if (_result != null) {
      final meal = Meal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _result!['name'] as String,
        calories: (_result!['calories'] as num).toInt(),
        protein: _result!['protein'] != null
            ? (_result!['protein'] as num).toInt()
            : null,
        carbs: _result!['carbs'] != null
            ? (_result!['carbs'] as num).toInt()
            : null,
        fat: _result!['fat'] != null ? (_result!['fat'] as num).toInt() : null,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        image: _selectedImage,
      );
      widget.storage.saveMeal(meal);
      widget.onNavigate('home');
    }
  }

  void _handleReset() {
    setState(() {
      _selectedImage = null;
      _result = null;
      _analyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Add Food',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track your meal',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: (_result != null || _selectedImage != null)
                ? _buildResultView()
                : _buildCaptureView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan Food section
        Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.orange[500], size: 20),
            const SizedBox(width: 8),
            const Text(
              'Scan Food',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildCaptureButton(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCaptureButton(
                icon: Icons.upload,
                label: 'Upload Photo',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Quick Add section
        Row(
          children: [
            Icon(Icons.restaurant, color: Colors.grey[500], size: 20),
            const SizedBox(width: 8),
            const Text(
              'Quick Add',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          children: _preconfiguredItems
              .map((item) => _buildQuickAddItem(item))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCaptureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: Colors.orange[600], size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _handleQuickAdd(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Text(item['icon'] as String, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${item['calories']} kcal',
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        // Analyzing state
        if (_analyzing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Analyzing Food...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we calculate calories',
                  style: TextStyle(color: AppTheme.mutedForeground),
                ),
              ],
            ),
          ),
        // Result card
        if (_result != null && !_analyzing) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _result!['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_result!['calories']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        ' kcal',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _macroChip('Protein', '${_result!['protein']}g'),
                    const SizedBox(width: 8),
                    _macroChip('Carbs', '${_result!['carbs']}g'),
                    const SizedBox(width: 8),
                    _macroChip('Fat', '${_result!['fat']}g'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _handleReset,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.muted,
                      foregroundColor: AppTheme.foreground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide.none,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Add Meal',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Note: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: 'Verify the nutritional information before saving.',
                  ),
                ],
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _macroChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
