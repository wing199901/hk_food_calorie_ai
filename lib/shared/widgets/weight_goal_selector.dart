import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class WeightGoalSelector extends StatelessWidget {
  const WeightGoalSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value; // 'lose' | 'maintain' | 'gain'
  final ValueChanged<String> onChanged;

  static const _options = [
    ('lose', 'Lose', Icons.trending_down),
    ('maintain', 'Maintain', Icons.horizontal_rule),
    ('gain', 'Gain', Icons.trending_up),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final isSelected = value == opt.$1;
        final isLast = opt.$1 == _options.last.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
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
                      size: 20,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.mutedForeground,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.foreground,
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
