import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import 'macro_ratio_ring.dart';

class MacroPreview extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;

  const MacroPreview({super.key, required this.weeklyData});

  int _percent(int value, int total) {
    if (total <= 0) return 0;
    return ((value / total) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final totalProtein = weeklyData.fold<int>(
      0,
      (sum, d) => sum + (d['protein'] as int),
    );
    final totalCarbs = weeklyData.fold<int>(
      0,
      (sum, d) => sum + (d['carbs'] as int),
    );
    final totalFat = weeklyData.fold<int>(
      0,
      (sum, d) => sum + (d['fat'] as int),
    );
    final total = totalProtein + totalCarbs + totalFat;

    final proteinPct = _percent(totalProtein, total);
    final carbsPct = _percent(totalCarbs, total);
    final fatPct = _percent(totalFat, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side: Macro list
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMacroText(
                'Protein',
                '$totalProtein g',
                const Color(0xFFEF4444),
              ),
              const SizedBox(height: 2),
              _buildMacroText('Carbs', '$totalCarbs g', AppTheme.primary),
              const SizedBox(height: 2),
              _buildMacroText('Fat', '$totalFat g', const Color(0xFFF59E0B)),
            ],
          ),
        ),
        // Right side: Ring Chart
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 56,
          height: 56,
          child: MacroRatioRing(
            proteinPct: proteinPct,
            carbsPct: carbsPct,
            fatPct: fatPct,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroText(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
