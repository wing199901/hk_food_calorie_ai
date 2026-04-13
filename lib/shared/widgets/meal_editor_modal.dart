import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../env/env.dart';
import '../models/meal.dart';
import '../providers/providers.dart';
import '../utils/storage_url_utils.dart';

class MealEditorModal extends ConsumerStatefulWidget {
  final DateTime date;
  final Meal? initialMeal;
  final String? modalTitle;
  final bool saveToStorage;

  const MealEditorModal({
    super.key,
    required this.date,
    this.initialMeal,
    this.modalTitle,
    this.saveToStorage = true,
  });

  @override
  ConsumerState<MealEditorModal> createState() => _MealEditorModalState();
}

class _MealEditorModalState extends ConsumerState<MealEditorModal> {
  late TextEditingController _nameCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  late TextEditingController _sugarCtrl;
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
    _sugarCtrl = TextEditingController(
      text: widget.initialMeal?.sugar?.toString() ?? '',
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
    _sugarCtrl.dispose();
    super.dispose();
  }

  String get _resolvedTitle {
    final custom = widget.modalTitle?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return widget.initialMeal != null ? 'Edit Meal' : 'Add Meal';
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
    final calories = int.tryParse(_caloriesCtrl.text.trim());
    if (name.isEmpty || calories == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter meal name and calories')),
      );
      return;
    }

    final protein = int.tryParse(_proteinCtrl.text.trim());
    final carbs = int.tryParse(_carbsCtrl.text.trim());
    final fat = int.tryParse(_fatCtrl.text.trim());
    final sugar = int.tryParse(_sugarCtrl.text.trim());
    final initialMeal = widget.initialMeal;

    final mealToSave = Meal(
      id: initialMeal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      timestamp: initialMeal?.timestamp ?? widget.date.millisecondsSinceEpoch,
      image: _image,
      imagePath: initialMeal?.imagePath,
    );

    if (widget.saveToStorage) {
      if (initialMeal != null) {
        ref.read(storageProvider).updateMeal(mealToSave);
      } else {
        ref.read(storageProvider).saveMeal(mealToSave);
      }
    }

    Navigator.pop(context, mealToSave);
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
                  _resolvedTitle,
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
              'Calories (kcal) *',
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
            _buildField('Sugar (g)', _sugarCtrl, '0', isNumber: true),
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
                        child: _isNetworkImage(_image!)
                            ? CachedNetworkImage(
                                imageUrl: _resolvedImageUrl(_image!),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  height: 160,
                                  width: double.infinity,
                                  color: AppTheme.muted,
                                ),
                                errorWidget: (_, _, _) => Container(
                                  height: 160,
                                  width: double.infinity,
                                  color: AppTheme.muted,
                                  child: const Icon(Icons.image),
                                ),
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

  bool _isNetworkImage(String path) {
    final parsed = Uri.tryParse(path);
    final looksLikeStoragePath =
        path.startsWith('/storage/v1/') ||
        path.startsWith('storage/v1/') ||
        (parsed != null && parsed.path.startsWith('/storage/v1/'));

    return path.startsWith('http') || looksLikeStoragePath;
  }

  String _resolvedImageUrl(String rawUrl) {
    return normalizeStorageUrl(rawUrl, baseUrl: Env.supabaseUrl);
  }
}
