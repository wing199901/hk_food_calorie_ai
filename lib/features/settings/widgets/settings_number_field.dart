import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SettingsNumberField extends StatelessWidget {
  const SettingsNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.unit,
    this.labelMinHeight,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? unit;
  final double? labelMinHeight;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelMinHeight != null)
          SizedBox(
            height: labelMinHeight,
            child: Align(alignment: Alignment.centerLeft, child: labelWidget),
          )
        else
          labelWidget,
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.mutedForeground),
            suffixText: unit,
            suffixStyle: TextStyle(
              color: AppTheme.foreground.withValues(alpha: 0.72),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : AppTheme.muted,
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
