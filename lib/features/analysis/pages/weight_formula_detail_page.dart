import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/detail_text_card.dart';

class WeightFormulaDetailPage extends StatelessWidget {
  final double? heightCm;
  final double? lowerKg;
  final double? upperKg;
  final double baseKg;
  final String heightText;
  final String lowerText;
  final String upperText;

  const WeightFormulaDetailPage({
    super.key,
    required this.heightCm,
    required this.lowerKg,
    required this.upperKg,
    required this.baseKg,
    required this.heightText,
    required this.lowerText,
    required this.upperText,
  });

  @override
  Widget build(BuildContext context) {
    final formulaLower = heightCm != null
        ? '18.5 x (${(heightCm! / 100).toStringAsFixed(2)}^2) = $lowerText'
        : '--';
    final formulaUpper = heightCm != null
        ? '${baseKg.toStringAsFixed(baseKg % 1 == 0 ? 0 : 1)} + 2.3 x (($heightText - 152.4) / 2.54) = $upperText'
        : '--';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text('How We Calculate Your Range'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DetailTextCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How the numbers are calculated',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. Base weight: 50 kg (male) or 45.5 kg (female).\n'
                    '2. Height adjustment: +2.3 kg per inch above 152.4 cm.\n'
                    '3. Minimum treshold comes from BMI 18.5.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DetailTextCard(
              child: Column(
                children: [
                  const Text(
                    'Math Formula',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Minimum treshold: BMI 18.5 x height(m)^2',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formulaLower,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Upper boundary: Base weight + 2.3 x ((height_cm - 152.4) / 2.54)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formulaUpper,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
