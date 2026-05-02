import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class DetailTextCard extends StatelessWidget {
  final Widget child;

  const DetailTextCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}
