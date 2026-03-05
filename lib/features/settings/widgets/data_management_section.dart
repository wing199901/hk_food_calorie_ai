import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_section.dart';

class DataManagementSection extends StatelessWidget {
  const DataManagementSection({super.key, required this.onClearData});

  final VoidCallback onClearData;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      icon: Icons.delete,
      iconColor: AppTheme.destructive,
      title: 'Data Management',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onClearData,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Clear All Meal Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.destructive.withValues(alpha: 0.1),
                foregroundColor: AppTheme.destructive,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This will permanently delete all your meal history. This action cannot be undone.',
            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
