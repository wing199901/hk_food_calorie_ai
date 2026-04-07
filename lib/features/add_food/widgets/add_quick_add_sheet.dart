import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/quick_add_item.dart';
import '../../../core/theme/app_theme.dart';

void showAddQuickAddSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> availableIcons,
}) {
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  itemCount: availableIcons.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final icon = availableIcons[index];
                    final isSelected = icon == selectedIcon;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedIcon = icon),
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
                          style: const TextStyle(
                            fontSize: 24,
                            fontFamilyFallback: ['Apple Color Emoji'],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _ManualField(
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
                    child: _ManualField(
                      controller: calCtrl,
                      label: 'Calories (kcal)',
                      hint: '0',
                      numeric: true,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ManualField(
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
                    child: _ManualField(
                      controller: carbsCtrl,
                      label: 'Carbs (g)',
                      hint: '0',
                      numeric: true,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ManualField(
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
                    child: _ManualField(
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
                    ref.read(storageProvider).addQuickAddItem(item);
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

class _ManualField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool numeric;
  final TextInputAction textInputAction;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _ManualField({
    required this.controller,
    required this.label,
    required this.hint,
    this.numeric = false,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            errorText!,
            style: const TextStyle(fontSize: 12, color: AppTheme.destructive),
          ),
        ],
      ],
    );
  }
}
