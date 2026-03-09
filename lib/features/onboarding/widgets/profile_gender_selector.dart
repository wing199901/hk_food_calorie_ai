import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProfileGenderSelector extends StatelessWidget {
  const ProfileGenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('male', 'Male', Icons.male),
    ('female', 'Female', Icons.female),
    ('other', 'Other', Icons.transgender),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final isSelected = value == opt.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt.$1 != 'other' ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                child: Column(
                  children: [
                    Icon(
                      opt.$3,
                      size: 24,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.mutedForeground,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
