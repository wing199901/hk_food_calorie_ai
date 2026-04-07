import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/body_metric.dart';
import '../../../shared/models/user_profile.dart';
import 'body_signal_graphic.dart';

class BodyPreview extends StatelessWidget {
  final List<BodyMetric> bodyData;
  final UserProfile profile;

  const BodyPreview({super.key, required this.bodyData, required this.profile});

  String _formatValue(double? value, {int fraction = 1}) {
    if (value == null) return '--';
    return value.toStringAsFixed(fraction);
  }

  @override
  Widget build(BuildContext context) {
    final latest = bodyData.isNotEmpty ? bodyData.last : null;
    final weight = latest?.weight ?? profile.weight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left side: Large weight value
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(weight),
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Text(
                'kg',
                style: TextStyle(
                  color: AppTheme.mutedForeground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Right side: Chart/Graphic
        const SizedBox(width: AppSpacing.sm),
        const SizedBox(
          width: 80,
          height: 48,
          child: Align(
            alignment: Alignment.bottomRight,
            child: BodySignalGraphic(),
          ),
        ),
      ],
    );
  }
}
