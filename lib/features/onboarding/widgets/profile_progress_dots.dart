import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProfileProgressDots extends StatelessWidget {
  const ProfileProgressDots({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(isActive: true),
        const SizedBox(width: 8),
        _dot(isActive: step >= 1),
        const SizedBox(width: 8),
        _dot(isActive: step == 2),
      ],
    );
  }

  Widget _dot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary : AppTheme.muted,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
