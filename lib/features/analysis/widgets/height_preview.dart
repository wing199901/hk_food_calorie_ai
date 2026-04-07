import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';

class HeightPreview extends StatelessWidget {
  final List<BodyMetric> bodyData;
  final DateTime currentWeekStart;
  final double? profileHeight;

  const HeightPreview({
    super.key,
    required this.bodyData,
    required this.currentWeekStart,
    this.profileHeight,
  });

  String _formatValue(double? value, {int fraction = 1}) {
    if (value == null) return '--';
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(fraction);
  }

  @override
  Widget build(BuildContext context) {
    double? displayHeight = profileHeight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(displayHeight),
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Padding(
                padding: EdgeInsets.only(
                  bottom: 2,
                ), // visually align unit closely with bottom
                child: Text(
                  'cm',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
