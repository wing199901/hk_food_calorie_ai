import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.appVersion});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.1),
            AppTheme.accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About FitCalorie',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track your meals, analyze your nutrition, and reach your fitness goals with AI-powered food recognition.',
            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            appVersion.isEmpty ? 'Version —' : appVersion,
            style: const TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
