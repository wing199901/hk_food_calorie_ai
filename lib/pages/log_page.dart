import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/date_navigator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/meal.dart';
import '../theme/app_theme.dart';

class LogPage extends StatefulWidget {
  final StorageService storage;

  const LogPage({super.key, required this.storage});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<Meal> meals = [];
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.storage.addListener(_loadData);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_loadData);
    super.dispose();
  }

  void _setDate(DateTime d) {
    setState(() => _date = d);
    _loadData();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      meals = widget.storage.getMealsForDate(_date);
    });
  }

  void _showMealModal({Meal? meal}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualMealModal(
        date: _date,
        storage: widget.storage,
        initialMeal: meal,
      ),
    );
  }

  int get _totalCalories => meals.fold<int>(0, (s, m) => s + m.calories);

  @override
  Widget build(BuildContext context) {
    return Column(
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Food Log',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    DateNavigator(date: _date, onDateChanged: _setDate),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Calories',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_totalCalories',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              ' kcal',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Meal list
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Meals (${meals.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showMealModal(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: meals.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppTheme.muted,
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    size: 32,
                                    color: AppTheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No meals recorded',
                                  style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add a meal manually or scan food',
                                  style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: meals.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final meal = meals[index];
                            return Dismissible(
                              key: Key(meal.id),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // Swipe right → edit
                                  _showMealModal(meal: meal);
                                  return false; // don't dismiss
                                }
                                // Swipe left → delete
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Meal'),
                                        content: const Text(
                                          'Are you sure you want to delete this meal?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: AppTheme.destructive,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              },
                              onDismissed: (_) {
                                widget.storage.deleteMeal(meal.id);
                              },
                              // Swipe-right background (edit)
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 24),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              // Swipe-left background (delete)
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: AppTheme.destructive,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              child: _buildMealCard(meal),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(Meal meal) {
    return GestureDetector(
      onTap: () => _showMealModal(meal: meal),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meal.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMealImage(meal.image!, 80, 80),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(
                      DateTime.fromMillisecondsSinceEpoch(meal.timestamp),
                    ),
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                  if (meal.protein != null ||
                      meal.carbs != null ||
                      meal.fat != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (meal.protein != null)
                          Text(
                            'P: ${meal.protein}g',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                        if (meal.carbs != null)
                          Text(
                            'C: ${meal.carbs}g',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                        if (meal.fat != null)
                          Text(
                            'F: ${meal.fat}g',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${meal.calories}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealImage(String imageUrl, double width, double height) {
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            Container(width: width, height: height, color: AppTheme.muted),
        errorWidget: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppTheme.muted,
          child: const Icon(Icons.image),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppTheme.muted,
          child: const Icon(Icons.image),
        ),
      );
    }
  }
}

// ─── Manual Meal Modal ───────────────────────────────────────

class _ManualMealModal extends StatefulWidget {
  final DateTime date;
  final StorageService storage;
  final Meal? initialMeal;

  const _ManualMealModal({
    required this.date,
    required this.storage,
    this.initialMeal,
  });

  @override
  State<_ManualMealModal> createState() => _ManualMealModalState();
}

class _ManualMealModalState extends State<_ManualMealModal> {
  late TextEditingController _nameCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  String? _image;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialMeal?.name ?? '');
    _caloriesCtrl = TextEditingController(
      text: widget.initialMeal?.calories.toString() ?? '',
    );
    _proteinCtrl = TextEditingController(
      text: widget.initialMeal?.protein?.toString() ?? '',
    );
    _carbsCtrl = TextEditingController(
      text: widget.initialMeal?.carbs?.toString() ?? '',
    );
    _fatCtrl = TextEditingController(
      text: widget.initialMeal?.fat?.toString() ?? '',
    );
    _image = widget.initialMeal?.image;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
    );
    if (picked != null) {
      setState(() => _image = picked.path);
    }
  }

  void _handleSave() {
    final name = _nameCtrl.text.trim();
    final calories = int.tryParse(_caloriesCtrl.text);
    if (name.isEmpty || calories == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter meal name and calories')),
      );
      return;
    }

    final protein = int.tryParse(_proteinCtrl.text);
    final carbs = int.tryParse(_carbsCtrl.text);
    final fat = int.tryParse(_fatCtrl.text);

    if (widget.initialMeal != null) {
      widget.storage.updateMeal(
        widget.initialMeal!.copyWith(
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          image: _image,
        ),
      );
    } else {
      widget.storage.saveMeal(
        Meal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          timestamp: widget.date.millisecondsSinceEpoch,
          image: _image,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialMeal != null
                      ? 'Edit Meal'
                      : 'Add Meal Manually',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildField('Meal Name', _nameCtrl, 'e.g., Grilled Chicken'),
            const SizedBox(height: 16),
            _buildField(
              'Calories (required)',
              _caloriesCtrl,
              '0',
              isNumber: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    'Protein (g)',
                    _proteinCtrl,
                    '0',
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    'Carbs (g)',
                    _carbsCtrl,
                    '0',
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField('Fat (g)', _fatCtrl, '0', isNumber: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Food Image',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _image!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: _image!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_image!),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.border,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: AppTheme.mutedForeground,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to upload photo',
                            style: TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.muted,
                        foregroundColor: AppTheme.foreground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide.none,
                      ),
                      child: const Text('Cancel'),
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
                      ),
                      child: Text(
                        widget.initialMeal != null
                            ? 'Save Changes'
                            : 'Save Meal',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.mutedForeground),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
