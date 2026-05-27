import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Visual snapshot of daily energy balance (TEE + surplus).
class EnergyBalanceSnapshot extends StatelessWidget {
  final int teeCalories;
  final int surplusCalories;

  const EnergyBalanceSnapshot({
    super.key,
    required this.teeCalories,
    required this.surplusCalories,
  });

  @override
  Widget build(BuildContext context) {
    final total = teeCalories + surplusCalories;
    final ratioBase = math.max(total, 1);
    final teeRatio = teeCalories / ratioBase;
    final surplusRatio = surplusCalories / ratioBase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily target: $total kcal',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(
              Icons.linear_scale,
              size: 16,
              color: AppTheme.mutedForeground,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Row(
                children: [
                  Text(
                    'TEE (burn)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Food intake (target)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final teeWidth = width * teeRatio;
            final surplusWidth = width * surplusRatio;

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: teeWidth,
                    height: 14,
                    color: AppTheme.primary,
                  ),
                  Container(
                    width: surplusWidth,
                    height: 14,
                    color: AppTheme.accent,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _valueColumn('TEE', '$teeCalories kcal', AppTheme.primary),
            const SizedBox(width: AppSpacing.sm),
            _valueColumn(
              '+ Surplus',
              '+$surplusCalories kcal',
              AppTheme.accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            _valueColumn('Target', '$total kcal', AppTheme.foreground),
          ],
        ),
      ],
    );
  }

  Widget _valueColumn(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
