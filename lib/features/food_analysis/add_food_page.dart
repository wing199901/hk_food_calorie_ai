import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/meal.dart';
import '../../shared/models/quick_add_item.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/quick_add_item_card.dart';
import 'widgets/result_view.dart';
import 'widgets/add_quick_add_sheet.dart';

class AddFoodPage extends ConsumerStatefulWidget {
  final Function(String) onNavigate;

  const AddFoodPage({
    super.key,
    required this.onNavigate,
  });

  @override
  ConsumerState<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends ConsumerState<AddFoodPage> {
  String? _selectedImage;
  bool _analyzing = false;
  Map<String, dynamic>? _result;
  bool _isEditMode = false;
  List<QuickAddItem> _quickAddItems = [];

  static const _availableIcons = [
    '🍚', '🥚', '🍌', '🍞', '☕', '🍗', '🍎', '🥛',
    '🍜', '🥗', '🍕', '🍔', '🌮', '🍣', '🍱', '🥟',
    '🍝', '🥩', '🍰', '🧁', '🍩', '🥤', '🍵', '🥐',
    '🍙', '🥪', '🍲', '🥘', '🫕', '🍽️',
  ];

  static const _foodDatabase = [
    {
      'name': 'BBQ Combo Rice',
      'calories': 750,
      'protein': 35,
      'carbs': 88,
      'fat': 28,
      'sugar': 6,
    },
    {
      'name': 'Pineapple Bun + Iced Milk Tea',
      'calories': 520,
      'protein': 8,
      'carbs': 62,
      'fat': 26,
      'sugar': 28,
    },
    {
      'name': 'Wonton Noodles',
      'calories': 380,
      'protein': 18,
      'carbs': 48,
      'fat': 12,
      'sugar': 4,
    },
    {
      'name': 'Char Siu Rice',
      'calories': 680,
      'protein': 32,
      'carbs': 85,
      'fat': 22,
      'sugar': 8,
    },
    {
      'name': 'Egg Tart',
      'calories': 220,
      'protein': 4,
      'carbs': 28,
      'fat': 10,
      'sugar': 12,
    },
    {
      'name': 'Dim Sum Platter (Har Gow, Siu Mai, Cheung Fun)',
      'calories': 580,
      'protein': 24,
      'carbs': 52,
      'fat': 28,
      'sugar': 6,
    },
    {
      'name': 'Pork Chop Bun',
      'calories': 450,
      'protein': 22,
      'carbs': 38,
      'fat': 24,
      'sugar': 4,
    },
    {
      'name': 'Fish Ball Noodles',
      'calories': 320,
      'protein': 16,
      'carbs': 42,
      'fat': 10,
      'sugar': 2,
    },
    {
      'name': 'Iced Lemon Tea',
      'calories': 120,
      'protein': 0,
      'carbs': 30,
      'fat': 0,
      'sugar': 28,
    },
    {
      'name': 'Claypot Rice',
      'calories': 620,
      'protein': 28,
      'carbs': 78,
      'fat': 22,
      'sugar': 6,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadQuickAddItems();
  }

  void _loadQuickAddItems() {
    setState(() {
      _quickAddItems = ref.read(storageProvider).getQuickAddItems();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1080);
    if (picked != null) {
      setState(() {
        _selectedImage = picked.path;
        _isEditMode = false;
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

  void _handleQuickAdd(QuickAddItem item) {
    if (_isEditMode) return;
    setState(() {
      _selectedImage = null;
      _result = {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
      };
    });
  }

  void _handleDeleteQuickAdd(QuickAddItem item) {
    HapticFeedback.mediumImpact();
    ref.read(storageProvider).removeQuickAddItem(item.id);
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
      ref.read(storageProvider).saveMeal(meal);
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

  void _enterEditMode() {
    HapticFeedback.heavyImpact();
    setState(() => _isEditMode = true);
  }

  void _exitEditMode() {
    setState(() => _isEditMode = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isEditMode ? _exitEditMode : null,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
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
                  child: Row(
                    children: [
                      Expanded(
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
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
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
                    ? ResultView(
                        isAnalyzing: _analyzing,
                        result: _result,
                        onSave: _handleSave,
                        onCancel: _handleReset,
                      )
                    : _buildCaptureView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan Meal section
        Row(
          children: [
            Icon(Icons.camera_alt, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Scan Meal',
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
        // Quick Add section header
        Row(
          children: [
            Icon(Icons.restaurant, color: AppTheme.mutedForeground, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: _isEditMode
                  ? const Text(
                      'Hold to delete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedForeground,
                      ),
                    )
                  : const Text(
                      'Quick Add',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            if (_isEditMode)
              GestureDetector(
                onTap: _exitEditMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => showAddQuickAddSheet(
                  context: context,
                  ref: ref,
                  availableIcons: _availableIcons,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_quickAddItems.isEmpty)
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
                const Text('🍽️', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                const Text(
                  'No quick add items',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap + to add your favourite foods',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            children: _quickAddItems
                .map(
                  (item) => QuickAddItemCard(
                    item: item,
                    isEditMode: _isEditMode,
                    onTap: () => _handleQuickAdd(item),
                    onLongPress: _enterEditMode,
                    onDelete: () => _handleDeleteQuickAdd(item),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 32),
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
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 24),
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
}
