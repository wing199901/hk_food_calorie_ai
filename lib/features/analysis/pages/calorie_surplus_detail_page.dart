import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../widgets/detail_text_card.dart';

class CalorieSurplusDetailPage extends StatelessWidget {
  const CalorieSurplusDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text('Why +500 kcal per Day?'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DetailTextCard(
              child: Text(
                'A common theory in nutrition is:\n\n'
                '7,700 kcal surplus ~= 1 kg body weight gain\n\n'
                'If your target is about 0.5 kg/week, the weekly surplus is roughly:\n'
                '0.5 x 7,700 = 3,850 kcal/week\n\n'
                'Daily surplus:\n'
                '3,850 / 7 ~= 550 kcal/day\n\n'
                'So +500 kcal/day is used as a practical and sustainable starting point. '
                'You can then adjust by weekly trend and appetite tolerance.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.foreground,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  MainScaffold.jumpToTab(2);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Go to Add tab to log intake',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                MainScaffold.jumpToTab(0);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Home energy overview'),
            ),
          ],
        ),
      ),
    );
  }
}
