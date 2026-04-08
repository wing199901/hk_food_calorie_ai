import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onSignOut,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.destructive,
          side: BorderSide(color: AppTheme.destructive.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
