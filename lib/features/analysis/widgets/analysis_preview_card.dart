import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

class AnalysisPreviewCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String lastUpdate;
  final VoidCallback onTap;
  final Widget child;

  const AnalysisPreviewCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.lastUpdate,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          constraints: const BoxConstraints(minHeight: 130),
          child: IntrinsicHeight(
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lastUpdate.isNotEmpty)
                            Text(
                              lastUpdate,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                          const SizedBox(width: AppSpacing.xxs),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppTheme.mutedForeground,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
