import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class BodySignalGraphic extends StatelessWidget {
  const BodySignalGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    const heights = [10.0, 22.0, 34.0, 46.0, 30.0, 18.0];
    return SizedBox(
      width: 96,
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(heights.length, (i) {
          return Container(
            width: 10,
            height: heights[i],
            decoration: BoxDecoration(
              color: AppTheme.mutedForeground.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }
}
