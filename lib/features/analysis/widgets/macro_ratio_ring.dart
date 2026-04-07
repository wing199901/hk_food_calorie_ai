import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class MacroRatioRing extends StatelessWidget {
  final int proteinPct;
  final int carbsPct;
  final int fatPct;

  const MacroRatioRing({
    super.key,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: CustomPaint(
        painter: _MacroRatioRingPainter(
          proteinPct: proteinPct,
          carbsPct: carbsPct,
          fatPct: fatPct,
        ),
      ),
    );
  }
}

class _MacroRatioRingPainter extends CustomPainter {
  final int proteinPct;
  final int carbsPct;
  final int fatPct;

  const _MacroRatioRingPainter({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 6);

    final basePaint = Paint()
      ..color = AppTheme.mutedForeground.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    final total = math.max(1, proteinPct + carbsPct + fatPct);
    final proteinSweep = (proteinPct / total) * math.pi * 2;
    final carbsSweep = (carbsPct / total) * math.pi * 2;
    final fatSweep = (fatPct / total) * math.pi * 2;
    double start = -math.pi / 2;

    void drawArc(Color color, double sweep) {
      if (sweep <= 0) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    drawArc(AppTheme.chartProtein, proteinSweep);
    drawArc(AppTheme.chartCarbs, carbsSweep);
    drawArc(AppTheme.chartFat, fatSweep);

    final centerDot = Paint()..color = AppTheme.foreground;
    canvas.drawCircle(center, 3, centerDot);
  }

  @override
  bool shouldRepaint(covariant _MacroRatioRingPainter oldDelegate) {
    return oldDelegate.proteinPct != proteinPct ||
        oldDelegate.carbsPct != carbsPct ||
        oldDelegate.fatPct != fatPct;
  }
}
