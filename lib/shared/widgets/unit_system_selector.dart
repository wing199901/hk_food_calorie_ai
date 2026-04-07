import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class UnitSystemSelector extends StatelessWidget {
  const UnitSystemSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value; // 'metric' | 'imperial'
  final ValueChanged<String> onChanged;

  static const _options = [
    ('metric', 'Metric', 'kg / cm'),
    ('imperial', 'Imperial', 'lbs / in'),
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
                    const SizedBox(height: 2),
                    Text(
                      opt.$3,
                      style: TextStyle(
                        fontSize: 12,
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
