import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../models/meal.dart';
import '../models/quick_add_item.dart';
import '../theme/app_theme.dart';

class AddFoodPage extends StatefulWidget {
  final Function(String) onNavigate;
  final StorageService storage;

  const AddFoodPage({
    super.key,
    required this.onNavigate,
    required this.storage,
  });

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
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
      'name': '燒味雙併飯',
      'calories': 750,
      'protein': 35,
      'carbs': 88,
      'fat': 28,
      'sugar': 6,
    },
    {
      'name': '菠蘿油 + 凍奶茶',
      'calories': 520,
      'protein': 8,
      'carbs': 62,
      'fat': 26,
      'sugar': 28,
    },
    {
      'name': '雲吞麵',
      'calories': 380,
      'protein': 18,
      'carbs': 48,
      'fat': 12,
      'sugar': 4,
    },
    {
      'name': '叉燒飯',
      'calories': 680,
      'protein': 32,
      'carbs': 85,
      'fat': 22,
      'sugar': 8,
    },
    {
      'name': '蛋撻',
      'calories': 220,
      'protein': 4,
      'carbs': 28,
      'fat': 10,
      'sugar': 12,
    },
    {
      'name': '點心拼盤（蝦餃、燒賣、腸粉）',
      'calories': 580,
      'protein': 24,
      'carbs': 52,
      'fat': 28,
      'sugar': 6,
    },
    {
      'name': '豬扒包',
      'calories': 450,
      'protein': 22,
      'carbs': 38,
      'fat': 24,
      'sugar': 4,
    },
    {
      'name': '魚蛋粉',
      'calories': 320,
      'protein': 16,
      'carbs': 42,
      'fat': 10,
      'sugar': 2,
    },
    {
      'name': '凍檸茶',
      'calories': 120,
      'protein': 0,
      'carbs': 30,
      'fat': 0,
      'sugar': 28,
    },
    {
      'name': '煲仔飯',
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
    widget.storage.addListener(_loadQuickAddItems);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_loadQuickAddItems);
    super.dispose();
  }

  void _loadQuickAddItems() {
    setState(() {
      _quickAddItems = widget.storage.getQuickAddItems();
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
    widget.storage.removeQuickAddItem(item.id);
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
                    ? _buildResultView()
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
                onTap: _openAddQuickAddSheet,
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
                .map((item) => _buildQuickAddItem(item))
                .toList(),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _openAddQuickAddSheet() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final sugarCtrl = TextEditingController();
    String selectedIcon = '🍽️';
    bool nameError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.muted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Quick Add Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                // Icon picker
                const Text(
                  'Icon',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableIcons.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final icon = _availableIcons[index];
                      final isSelected = icon == selectedIcon;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedIcon = icon),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : AppTheme.muted,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppTheme.accent, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _manualField(
                  controller: nameCtrl,
                  label: 'Food Name',
                  hint: 'e.g. Chicken Rice',
                  textInputAction: TextInputAction.next,
                  errorText: nameError ? 'Food name is required' : null,
                  onChanged: (_) {
                    if (nameError) setSheetState(() => nameError = false);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _manualField(
                        controller: calCtrl,
                        label: 'Calories (kcal)',
                        hint: '0',
                        numeric: true,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _manualField(
                        controller: proteinCtrl,
                        label: 'Protein (g)',
                        hint: '0',
                        numeric: true,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _manualField(
                        controller: carbsCtrl,
                        label: 'Carbs (g)',
                        hint: '0',
                        numeric: true,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _manualField(
                        controller: fatCtrl,
                        label: 'Fat (g)',
                        hint: '0',
                        numeric: true,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _manualField(
                        controller: sugarCtrl,
                        label: 'Sugar (g)',
                        hint: '0',
                        numeric: true,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setSheetState(() => nameError = true);
                        return;
                      }
                      Navigator.pop(ctx);
                      final item = QuickAddItem(
                        id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        calories: int.tryParse(calCtrl.text) ?? 0,
                        protein: int.tryParse(proteinCtrl.text) ?? 0,
                        carbs: int.tryParse(carbsCtrl.text) ?? 0,
                        fat: int.tryParse(fatCtrl.text) ?? 0,
                        sugar: int.tryParse(sugarCtrl.text) ?? 0,
                        icon: selectedIcon,
                      );
                      widget.storage.addQuickAddItem(item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Quick Add',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool numeric = false,
    TextInputAction textInputAction = TextInputAction.next,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: hasError ? AppTheme.destructive : null,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          textInputAction: textInputAction,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.mutedForeground),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppTheme.destructive : AppTheme.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppTheme.destructive : AppTheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[  
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.destructive,
            ),
          ),
        ],
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

  Widget _buildQuickAddItem(QuickAddItem item) {
    return GestureDetector(
      onTap: () => _handleQuickAdd(item),
      onLongPress: _isEditMode ? null : _enterEditMode,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _isEditMode
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isEditMode
                    ? AppTheme.destructive.withValues(alpha: 0.3)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Text(
                  item.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.calories} kcal',
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
          // iOS-style delete badge
          if (_isEditMode)
            Positioned(
              top: -8,
              left: -8,
              child: GestureDetector(
                onTap: () => _handleDeleteQuickAdd(item),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppTheme.destructive,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
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
                  'Analyzing Meal...',
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
