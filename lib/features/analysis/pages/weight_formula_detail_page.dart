import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../widgets/abw_formula_simulator.dart';
import '../widgets/detail_text_card.dart';

class WeightFormulaDetailPage extends ConsumerStatefulWidget {
  final double? heightCm;
  final double? lowerKg;
  final double? upperKg;
  final double baseKg;
  final String heightText;
  final String lowerText;
  final String upperText;
  final double? currentWeightKg;
  final String? gender;
  final String? unitSystem;

  const WeightFormulaDetailPage({
    super.key,
    required this.heightCm,
    required this.lowerKg,
    required this.upperKg,
    required this.baseKg,
    required this.heightText,
    required this.lowerText,
    required this.upperText,
    required this.currentWeightKg,
    required this.gender,
    required this.unitSystem,
  });

  @override
  ConsumerState<WeightFormulaDetailPage> createState() =>
      _WeightFormulaDetailPageState();
}

class _WeightFormulaDetailPageState
    extends ConsumerState<WeightFormulaDetailPage> {

  @override
  Widget build(BuildContext context) {
    ref.watch(storageSignalProvider);
    final formulaLower = widget.heightCm != null
        ? '18.5 x (${(widget.heightCm! / 100).toStringAsFixed(2)}^2) = ${widget.lowerText}'
        : '--';
    final formulaUpper = widget.heightCm != null
        ? '${widget.baseKg.toStringAsFixed(widget.baseKg % 1 == 0 ? 0 : 1)} + 2.3 x ((${widget.heightText} - 152.4) / 2.54) = ${widget.upperText}'
        : '--';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text('How We Calculate Your Target Range'),
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
                    '3. Minimum threshold comes from BMI 18.5.',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 360;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _formulaColumn(
                              title: 'Healthy minimum (BMI 18.5)',
                              subtitle: 'BMI 18.5 x height(m)^2',
                              value: formulaLower,
                              accentColor: AppTheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _formulaColumn(
                              title: 'Ideal target (IBW)',
                              subtitle:
                                  'Base weight + 2.3 x ((height_cm - 152.4) / 2.54)',
                              value: formulaUpper,
                              accentColor: AppTheme.chartWeight,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _formulaColumn(
                              title: 'Healthy minimum (BMI 18.5)',
                              subtitle: 'BMI 18.5 x height(m)^2',
                              value: formulaLower,
                              accentColor: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _formulaColumn(
                              title: 'Ideal target (IBW)',
                              subtitle:
                                  'Base weight + 2.3 x ((height_cm - 152.4) / 2.54)',
                              value: formulaUpper,
                              accentColor: AppTheme.chartWeight,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DetailTextCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'When we use IBW vs ABW',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'IBW here follows the Devine base + height adjustment shown above.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.foreground,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text: 'If actual weight > 120% of IBW, we use ABW for energy targets.\n',
                        ),
                        TextSpan(
                          text: 'ABW = IBW + 0.4 x (Actual - IBW)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        TextSpan(
                          text: '\nOtherwise, we use actual weight.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AbwFormulaSimulatorCard(
              heightCm: widget.heightCm,
              gender: widget.gender,
              unitSystem: widget.unitSystem,
              initialWeightKg: widget.currentWeightKg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaColumn({
    required String title,
    required String subtitle,
    required String value,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: accentColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.mutedForeground,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.foreground,
          ),
        ),
      ],
    );
  }
}
