import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/meal.dart';
import '../../shared/models/quick_add_item.dart';
import '../../shared/services/food_analysis_service.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/quick_add_item_card.dart';
import 'widgets/result_view.dart';
import 'widgets/add_quick_add_sheet.dart';

class AddFoodPage extends ConsumerStatefulWidget {
  final Function(String) onNavigate;
  final bool showTestControls;

  const AddFoodPage({
    super.key,
    required this.onNavigate,
    this.showTestControls = false,
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
    '🍚',
    '🥚',
    '🍌',
    '🍞',
    '☕',
    '🍗',
    '🍎',
    '🥛',
    '🍜',
    '🥗',
    '🍕',
    '🍔',
    '🌮',
    '🍣',
    '🍱',
    '🥟',
    '🍝',
    '🥩',
    '🍰',
    '🧁',
    '🍩',
    '🥤',
    '🍵',
    '🥐',
    '🍙',
    '🥪',
    '🍲',
    '🥘',
    '🫕',
    '🍽️',
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
        _result = null;
        _isEditMode = false;
      });
      await _analyzeImage(picked.path);
    }
  }

  Future<void> _analyzeImage(String imagePath) async {
    setState(() {
      _analyzing = true;
      _result = null;
    });

    try {
      final result = await ref
          .read(foodAnalysisServiceProvider)
          .analyzeImage(imagePath);
      if (!mounted) return;
      setState(() {
        _result = result;
        final imageUrl = result['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _selectedImage = imageUrl;
        }
      });

      // User confirmed upload when selecting the photo, so persist immediately.
      _saveAnalyzedMeal(result);
      widget.onNavigate('home');
    } on FoodAnalysisException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Unable to analyze this meal right now. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  void _saveAnalyzedMeal(Map<String, dynamic> result) {
    final imageUrl = result['image_url'] as String?;
    final meal = Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: result['name'] as String,
      calories: (result['calories'] as num).toInt(),
      protein: result['protein'] != null
          ? (result['protein'] as num).toInt()
          : null,
      carbs: result['carbs'] != null ? (result['carbs'] as num).toInt() : null,
      fat: result['fat'] != null ? (result['fat'] as num).toInt() : null,
      sugar: result['sugar'] != null ? (result['sugar'] as num).toInt() : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      image: imageUrl ?? _selectedImage,
    );
    ref.read(storageProvider).saveMeal(meal);
  }

  void _handleQuickAdd(QuickAddItem item) {
    if (_isEditMode) return;

    // Set the result to show confirmation screen
    setState(() {
      _selectedImage = null;
      _result = {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'sugar': item.sugar,
      };
    });
  }

  void _handleDeleteQuickAdd(QuickAddItem item) {
    HapticFeedback.mediumImpact();
    ref.read(storageProvider).removeQuickAddItem(item.id);
    _loadQuickAddItems();
  }

  void _handleSave() {
    if (_result != null) {
      final imageUrl = _result!['image_url'] as String?;
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
        sugar: _result!['sugar'] != null
            ? (_result!['sugar'] as num).toInt()
            : null,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        image: imageUrl ?? _selectedImage,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        if (widget.showTestControls) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('test_analyze_valid_photo'),
                  onPressed: () => _analyzeImage('meal.jpg'),
                  child: const Text('Test Analyze Valid Photo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('test_analyze_invalid_photo'),
                  onPressed: () => _analyzeImage('meal.txt'),
                  child: const Text('Test Analyze Invalid Photo'),
                ),
              ),
            ],
          ),
        ],
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
                const Text(
                  '🍽️',
                  style: TextStyle(
                    fontSize: 32,
                    fontFamilyFallback: ['Apple Color Emoji'],
                  ),
                ),
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
            key: const Key('quick_add_grid'),
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
