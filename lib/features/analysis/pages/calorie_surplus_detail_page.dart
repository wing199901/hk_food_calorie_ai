import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/storage_service.dart';
import '../../../main.dart';
import '../widgets/energy_balance_snapshot.dart';
import '../widgets/detail_text_card.dart';

class CalorieSurplusDetailPage extends ConsumerStatefulWidget {
  const CalorieSurplusDetailPage({super.key});

  @override
  ConsumerState<CalorieSurplusDetailPage> createState() =>
      _CalorieSurplusDetailPageState();
}

class _CalorieSurplusDetailPageState
    extends ConsumerState<CalorieSurplusDetailPage> {
  @override
  Widget build(BuildContext context) {
    ref.watch(storageSignalProvider);
    final storage = ref.read(storageProvider);
    final profile = storage.getUserProfile();
    final milestone = _buildMilestoneForecast(profile);
    final tee = StorageService.calculateTEE(profile);
    const surplus = 500;
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
            DetailTextCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How the surplus is calculated',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'A common nutrition estimate is that 7,700 kcal surplus ~= 1 kg body weight gain.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.foreground,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(text: 'Target gain: '),
                        const TextSpan(
                          text: '0.5 kg/week\n',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(text: 'Weekly surplus: '),
                        const TextSpan(
                          text: '0.5 x 7,700 = 3,850 kcal/week\n',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(text: 'Daily surplus: '),
                        const TextSpan(
                          text: '3,850 / 7 ~= 550 kcal/day',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (milestone != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildMilestoneTimeline(
                      milestoneLabel: milestone.milestoneLabel,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      milestone.helperText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                    if (milestone.targetText != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        milestone.targetText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedForeground,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'That is why +500 kcal/day is used as a practical starting point.',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why +500 kcal is a practical start',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Smaller surpluses can be offset by NEAT (extra daily movement), so +500 kcal/day helps create a real net surplus.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Going much higher tends to add more fat and can feel heavy on digestion. Adjust up or down based on weekly weight trend and appetite tolerance.',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Energy Balance Snapshot',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  EnergyBalanceSnapshot(
                    teeCalories: tee,
                    surplusCalories: surplus,
                  ),
                ],
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
                  'Go to log your intake',
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

  _MilestoneForecast? _buildMilestoneForecast(UserProfile profile) {
    final currentWeight = profile.weight;
    final targetWeight = profile.targetWeight;

    if (currentWeight == null ||
        targetWeight == null ||
        targetWeight <= currentWeight) {
      return null;
    }

    final remainingKg = targetWeight - currentWeight;
    if (remainingKg <= 0) return null;

    // Use 25% of remaining gain as the next step to keep momentum realistic.
    final stepKg = _roundToStep(remainingKg * 0.25, 0.5);
    final milestoneGainKg = math.min(remainingKg, math.max(0.5, stepKg));
    final weeksToMilestone = milestoneGainKg / 0.5;
    final weeksToTarget = remainingKg / 0.5;

    final isMetric = profile.unitSystem != 'imperial';
    final milestoneText = UnitConverter.formatWeight(
      milestoneGainKg,
      isMetric: isMetric,
    );
    final helperText =
        'Estimated ~${_formatWeeks(weeksToMilestone)} weeks to next milestone '
        '(based on +0.5 kg/week; depends on consistency).';

    String? targetText;
    if (weeksToTarget - weeksToMilestone >= 2) {
      targetText =
          'Full target ~${_formatWeeks(weeksToTarget)} weeks at the same pace.';
    }

    return _MilestoneForecast(
      milestoneLabel: 'Next milestone (+$milestoneText)',
      helperText: helperText,
      targetText: targetText,
    );
  }

  double _roundToStep(double value, double step) {
    return (value / step).round() * step;
  }

  String _formatWeeks(double weeks) {
    if (weeks <= 1) return '1';
    if (weeks < 10) return weeks.toStringAsFixed(1);
    return weeks.round().toString();
  }

  Widget _buildMilestoneTimeline({required String milestoneLabel}) {
    return Column(
      children: [
        Row(
          children: [
            _timelineDot(isActive: false),
            Expanded(child: _timelineLine()),
            _timelineDot(isActive: true),
            Expanded(child: _timelineLine()),
            _timelineDot(isActive: false),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _timelineLabel(
                'Today',
                isActive: false,
              ),
            ),
            Expanded(
              child: _timelineLabel(
                milestoneLabel,
                isActive: true,
              ),
            ),
            Expanded(
              child: _timelineLabel(
                'Target',
                isActive: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timelineDot({required bool isActive}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary : AppTheme.mutedForeground,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _timelineLine() {
    return Container(
      height: 2,
      color: AppTheme.border,
    );
  }

  Widget _timelineLabel(String text, {required bool isActive}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
        color: isActive ? AppTheme.primary : AppTheme.mutedForeground,
        height: 1.2,
      ),
    );
  }
}

class _MilestoneForecast {
  final String milestoneLabel;
  final String helperText;
  final String? targetText;

  const _MilestoneForecast({
    required this.milestoneLabel,
    required this.helperText,
    required this.targetText,
  });
}
