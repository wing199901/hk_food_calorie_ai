import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final Color? titleColor;
  final bool showTitleBadge;
  final Widget child;
  final Widget? header;
  final Widget? summary;
  final List<Widget>? legend;
  final Widget? expandedDetail;

  const ChartCard({
    super.key,
    required this.title,
    this.titleIcon,
    this.titleColor,
    this.showTitleBadge = true,
    required this.child,
    this.header,
    this.summary,
    this.legend,
    this.expandedDetail,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = showTitleBadge ? 24.0 : 16.0;
    final topMargin = showTitleBadge ? 8.0 : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
          margin: EdgeInsets.only(top: topMargin),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) header!,
              if (header != null) const SizedBox(height: 16),
              child,
              if (expandedDetail != null) ...[
                const SizedBox(height: 8),
                expandedDetail!,
              ],
              if (summary != null) summary!,
              if (legend != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: legend!,
                ),
              ],
            ],
          ),
        ),
        if (showTitleBadge)
          Positioned(
            top: 0,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titleIcon != null) ...[
                    Icon(
                      titleIcon,
                      size: 14,
                      color: titleColor ?? AppTheme.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SummaryChip extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const SummaryChip({
    super.key,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DetailChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
