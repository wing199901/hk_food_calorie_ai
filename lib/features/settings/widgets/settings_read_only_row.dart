import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SettingsReadOnlyRow extends StatelessWidget {
  const SettingsReadOnlyRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white : AppTheme.muted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.calendar_today,
                size: 20,
                color: AppTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
