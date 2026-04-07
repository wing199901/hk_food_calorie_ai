import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class MiniEnergyBars extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;

  const MiniEnergyBars({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final values = weeklyData
        .map((d) => (d['calories'] as int).toDouble())
        .toList();
    final maxValue = values.isEmpty
        ? 1.0
        : math.max(1.0, values.reduce(math.max));
    final avg = values.isEmpty
        ? 0.0
        : values.fold<double>(0, (sum, value) => sum + value) / values.length;
    final avgTop = (1 - (avg / maxValue).clamp(0.0, 1.0)) * 54;

    return SizedBox(
      width: 112,
      height: 72,
      child: Stack(
        children: [
          Positioned(
            top: avgTop,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppTheme.chartWeight,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
              final barHeight = values[i] <= 0 ? 8.0 : 8 + ratio * 46;
              return Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 10,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.mutedForeground.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
