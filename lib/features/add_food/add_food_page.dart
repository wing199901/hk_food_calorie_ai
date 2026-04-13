import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/meal.dart';
import '../../shared/models/quick_add_item.dart';
import '../../shared/services/food_analysis_service.dart';
import '../../shared/utils/storage_url_utils.dart';
import '../../shared/widgets/meal_editor_modal.dart';
import '../../core/theme/app_theme.dart';
import '../../env/env.dart';
import 'widgets/quick_add_item_card.dart';
import 'widgets/result_view.dart';
import 'widgets/add_quick_add_sheet.dart';

class AddFoodPage extends ConsumerStatefulWidget {
  final Function(String) onNavigate;
  final ValueChanged<String>? onAnalysisFailed;
  final bool showTestControls;

  const AddFoodPage({
    super.key,
    required this.onNavigate,
    this.onAnalysisFailed,
    this.showTestControls = false,
  });

  @override
  ConsumerState<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends ConsumerState<AddFoodPage> {
  String? _selectedImage;
  bool _analyzing = false;
  bool _saving = false;
  Map<String, dynamic>? _result;
  bool _analysisEdited = false;
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
        _analysisEdited = false;
        _isEditMode = false;
      });
      await _analyzeImage(picked.path);
    }
  }

  Future<void> _analyzeImage(String imagePath) async {
    setState(() {
      _analyzing = true;
      _saving = false;
      _result = null;
    });

    try {
      final result = await ref
          .read(foodAnalysisServiceProvider)
          .analyzeImage(imagePath);
      if (!mounted) return;
      setState(() {
        _result = result;
        _analysisEdited = false;
        final image = result['image'] as Map<String, dynamic>?;
        final imageUrl = image?['url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _selectedImage = _normalizeMealImageUrl(imageUrl);
        }
      });
    } on FoodAnalysisException catch (error) {
      if (!mounted) return;
      _handleAnalyzeFailure(error.message);
    } catch (_) {
      if (!mounted) return;
      _handleAnalyzeFailure(
        'Unable to analyze this meal right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  void _handleAnalyzeFailure(String message) {
    setState(() {
      _selectedImage = null;
      _result = null;
      _analysisEdited = false;
    });

    final onAnalysisFailed = widget.onAnalysisFailed;
    if (onAnalysisFailed != null && _isRetryLaterFailure(message)) {
      onAnalysisFailed(message);
      return;
    }

    _showError(message);
  }

  bool _isRetryLaterFailure(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('unable to analyze this meal right now') ||
        normalized.contains('network error');
  }

  Meal _buildMealFromResult(Map<String, dynamic> result) {
    final image = result['image'] as Map<String, dynamic>?;
    final meal = result['meal'] as Map<String, dynamic>?;
    final totals = meal?['totals'] as Map<String, dynamic>?;
    final imageUrl = image?['url'] as String?;
    final imagePath = image?['path'] as String?;
    final calories = (totals?['calories'] as num?)?.toInt() ?? 0;
    final protein = (totals?['protein'] as num?)?.toInt();
    final carbs = (totals?['carbs'] as num?)?.toInt();
    final fat = (totals?['fat'] as num?)?.toInt();
    final sugar = (totals?['sugar'] as num?)?.toInt();

    return Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: result['name'] as String,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      image: (imageUrl != null && imageUrl.isNotEmpty)
          ? _normalizeMealImageUrl(imageUrl)
          : _selectedImage,
      imagePath: imagePath,
    );
  }

  void _handleQuickAdd(QuickAddItem item) {
    if (_isEditMode) return;

    // Set the result to show confirmation screen
    setState(() {
      _selectedImage = null;
      _analysisEdited = false;
      _result = {
        'name': item.name,
        'meal': {
          'date': _todayIsoDate(),
          'items': const <Map<String, dynamic>>[],
          'totals': {
            'calories': item.calories,
            'protein': item.protein,
            'carbs': item.carbs,
            'fat': item.fat,
            'sugar': item.sugar,
          },
        },
      };
    });
  }

  void _handleDeleteQuickAdd(QuickAddItem item) {
    HapticFeedback.mediumImpact();
    ref.read(storageProvider).removeQuickAddItem(item.id);
    _loadQuickAddItems();
  }

  Future<void> _handleSave() async {
    if (_result == null || _saving) return;

    setState(() => _saving = true);
    final meal = _buildMealFromResult(_result!);
    ref.read(storageProvider).saveMeal(meal);

    try {
      final analysisId = (_result!['analysis_id'] as String?)?.trim();
      if (analysisId != null && analysisId.isNotEmpty) {
        await ref
            .read(supabaseProvider)
            .saveAiMealAnalysisFeedback(
              analysisId: analysisId,
              mealRecordId: meal.id,
              isCorrect: !_analysisEdited,
              finalResult: _result!,
            );
      }
    } catch (_) {
      if (mounted) {
        _showError('Meal saved, but failed to sync AI feedback.');
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onNavigate('home');
  }

  void _handleReset() {
    setState(() {
      _selectedImage = null;
      _result = null;
      _analyzing = false;
      _saving = false;
      _analysisEdited = false;
    });
  }

  Future<void> _handleEditResult() async {
    if (_result == null || _saving) return;

    final baseResult = _result!;
    final editedMeal = await _openMealEditorModal(baseResult);
    if (!mounted || editedMeal == null) return;

    setState(() {
      _result = _mergeResultWithEditedMeal(baseResult, editedMeal);
      _selectedImage = editedMeal.image;
      _analysisEdited = true;
    });
  }

  Future<Meal?> _openMealEditorModal(
    Map<String, dynamic> currentResult,
  ) async {
    final initialMeal = _buildEditableMeal(currentResult);

    return await showModalBottomSheet<Meal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MealEditorModal(
        date: _resolveMealDate(currentResult),
        initialMeal: initialMeal,
        modalTitle: 'Edit AI Result',
        saveToStorage: false,
      ),
    );
  }

  Meal _buildEditableMeal(Map<String, dynamic> currentResult) {
    final image = _toMutableMap(currentResult['image']);
    final meal = _toMutableMap(currentResult['meal']);
    final totals = _toMutableMap(meal['totals']);

    final imageUrl = image['url'] as String?;
    final imagePath = image['path'] as String?;
    final id = (currentResult['analysis_id'] as String?) ??
        DateTime.now().millisecondsSinceEpoch.toString();

    return Meal(
      id: id,
      name: (currentResult['name'] as String?)?.trim().isNotEmpty == true
          ? (currentResult['name'] as String).trim()
          : 'AI Scanned Meal',
      calories: _toInt(totals['calories']),
      protein: _toOptionalInt(totals['protein']),
      carbs: _toOptionalInt(totals['carbs']),
      fat: _toOptionalInt(totals['fat']),
      sugar: _toOptionalInt(totals['sugar']),
      timestamp: _resolveMealDate(currentResult).millisecondsSinceEpoch,
      image: (imageUrl != null && imageUrl.isNotEmpty)
          ? _normalizeMealImageUrl(imageUrl)
          : _selectedImage,
      imagePath: imagePath,
    );
  }

  Map<String, dynamic> _mergeResultWithEditedMeal(
    Map<String, dynamic> currentResult,
    Meal editedMeal,
  ) {
    final updatedResult = Map<String, dynamic>.from(currentResult)
      ..['name'] = editedMeal.name;

    final updatedMeal = _toMutableMap(currentResult['meal'])
      ..['totals'] = {
        'calories': editedMeal.calories,
        'protein': editedMeal.protein ?? 0,
        'carbs': editedMeal.carbs ?? 0,
        'fat': editedMeal.fat ?? 0,
        'sugar': editedMeal.sugar ?? 0,
      };

    final rawItems = updatedMeal['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      final normalizedItems = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final first = normalizedItems.first;
      first['name_en'] = editedMeal.name;
      first['calories'] = editedMeal.calories;
      first['protein'] = editedMeal.protein ?? 0;
      first['carbs'] = editedMeal.carbs ?? 0;
      first['fat'] = editedMeal.fat ?? 0;
      first['sugar'] = editedMeal.sugar ?? 0;
      updatedMeal['items'] = normalizedItems;
    }

    updatedResult['meal'] = updatedMeal;

    final updatedImage = _toMutableMap(currentResult['image']);
    if (editedMeal.image != null && editedMeal.image!.trim().isNotEmpty) {
      updatedImage['url'] = editedMeal.image;
    } else {
      updatedImage.remove('url');
    }

    if (editedMeal.imagePath != null && editedMeal.imagePath!.isNotEmpty) {
      updatedImage['path'] = editedMeal.imagePath;
    }

    if (updatedImage.isNotEmpty) {
      updatedResult['image'] = updatedImage;
    }

    return updatedResult;
  }

  Map<String, dynamic> _toMutableMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  int? _toOptionalInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  DateTime _resolveMealDate(Map<String, dynamic> currentResult) {
    final meal = _toMutableMap(currentResult['meal']);
    final rawDate = meal['date'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate.trim());
      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.now();
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

  String _todayIsoDate() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _normalizeMealImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final parsed = Uri.tryParse(trimmed);
    final looksLikeStoragePath =
        trimmed.startsWith('/storage/v1/') ||
        trimmed.startsWith('storage/v1/') ||
        (parsed != null && parsed.path.startsWith('/storage/v1/'));

    if (!looksLikeStoragePath) {
      return trimmed;
    }

    return normalizeStorageUrl(trimmed, baseUrl: Env.supabaseUrl);
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
                        onSave: () => _handleSave(),
                        onEdit: () => _handleEditResult(),
                        onCancel: _handleReset,
                        isEdited: _analysisEdited,
                        isSaving: _saving,
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
