import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProfileActivitySelector extends StatelessWidget {
  const ProfileActivitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _levels = [
    ('sedentary', 'Sedentary', 'Little/no exercise'),
    ('light', 'Light', '1-3 days/week'),
    ('moderate', 'Moderate', '3-5 days/week'),
    ('active', 'Active', '6-7 days/week'),
    ('very-active', 'Very Active', '2x per day'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _levels.map((level) {
        final isSelected = value == level.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChanged(level.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.$2,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.foreground,
                          ),
                        ),
                        Text(
                          level.$3,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      size: 24,
                      color: AppTheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
