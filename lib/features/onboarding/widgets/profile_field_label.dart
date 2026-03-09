import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProfileFieldLabel extends StatelessWidget {
  const ProfileFieldLabel(this.label, {super.key, this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: AppTheme.destructive)),
      ],
    );
  }
}
