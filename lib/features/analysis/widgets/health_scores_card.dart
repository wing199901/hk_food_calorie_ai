import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/utils/health_score_utils.dart';
import '../../../core/theme/app_theme.dart';
import 'chart_card.dart';

class HealthScoresCard extends ConsumerWidget {
  const HealthScoresCard({super.key});

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppTheme.chartWeight;
    if (bmi < 25) return AppTheme.primary;
    if (bmi < 30) return AppTheme.warning;
    return AppTheme.destructive;
  }

  Color _whtrColor(double r) {
    if (r < 0.4) return AppTheme.chartWeight;
    if (r < 0.5) return AppTheme.primary;
    if (r < 0.6) return AppTheme.warning;
    return AppTheme.destructive;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storageSignalProvider);
    final storage = ref.read(storageProvider);
    final profile = storage.getUserProfile();
    final bmi = HealthScoreUtils.calculateBMIFromProfile(profile);
    final whtr = HealthScoreUtils.calculateWHtRFromProfile(profile);
    final tee = StorageService.calculateTEE(profile);

    return Column(
      children: [
        _scoreCard(
          title: 'Total Energy Expenditure',
          icon: Icons.local_fire_department_outlined,
          value: '$tee',
          unit: 'kcal/day',
          valueColor: AppTheme.accent,
          summary: Row(
            children: [
              _metaPill(
                label: 'Daily Target',
                value: '$tee kcal',
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              _metaPill(
                label: 'Activity',
                value: HealthScoreUtils.activityLabel(profile.activityLevel),
                color: AppTheme.primary,
              ),
            ],
          ),
          child: _meter(
            current: tee.toDouble(),
            min: 1200,
            max: 3600,
            bands: const [
              _MeterBand(start: 1200, end: 1700, color: AppTheme.chartWeight),
              _MeterBand(start: 1700, end: 2500, color: AppTheme.primary),
              _MeterBand(start: 2500, end: 3000, color: AppTheme.warning),
              _MeterBand(start: 3000, end: 3600, color: AppTheme.destructive),
            ],
            currentColor: AppTheme.accent,
            leftLabel: 'Lower burn',
            rightLabel: 'Higher burn',
            note: 'Estimated from profile + activity level',
            currentLabel: tee.toString(),
          ),
        ),
        const SizedBox(height: 24),
        _scoreCard(
          title: 'Body Mass Index (BMI)',
          icon: Icons.monitor_weight_outlined,
          value: bmi.toStringAsFixed(1),
          valueColor: _bmiColor(bmi),
          summary: Row(
            children: [
              _metaPill(
                label: 'Status',
                value: HealthScoreUtils.bmiCategory(bmi),
                color: _bmiColor(bmi),
              ),
              const SizedBox(width: 8),
              _metaPill(
                label: 'Healthy Range',
                value: '18.5 - 24.9',
                color: AppTheme.primary,
              ),
            ],
          ),
          child: _meter(
            current: bmi,
            min: 15,
            max: 35,
            bands: const [
              _MeterBand(start: 15, end: 18.5, color: AppTheme.chartWeight),
              _MeterBand(start: 18.5, end: 24.9, color: AppTheme.primary),
              _MeterBand(start: 24.9, end: 29.9, color: AppTheme.warning),
              _MeterBand(start: 29.9, end: 35, color: AppTheme.destructive),
            ],
            currentColor: _bmiColor(bmi),
            leftLabel: 'Under',
            rightLabel: 'Obese',
            note: 'Healthy range: 18.5 - 24.9',
            currentLabel: bmi.toStringAsFixed(1),
          ),
        ),
        const SizedBox(height: 24),
        _scoreCard(
          title: 'Waist-to-Height Ratio',
          icon: Icons.straighten,
          value: whtr.toStringAsFixed(2),
          valueColor: _whtrColor(whtr),
          summary: Row(
            children: [
              _metaPill(
                label: 'Status',
                value: HealthScoreUtils.whtrCategory(whtr),
                color: _whtrColor(whtr),
              ),
              const SizedBox(width: 8),
              _metaPill(
                label: 'Healthy Target',
                value: '< 0.50',
                color: AppTheme.primary,
              ),
            ],
          ),
          child: _meter(
            current: whtr,
            min: 0.35,
            max: 0.70,
            bands: const [
              _MeterBand(start: 0.35, end: 0.40, color: AppTheme.chartWeight),
              _MeterBand(start: 0.40, end: 0.50, color: AppTheme.primary),
              _MeterBand(start: 0.50, end: 0.60, color: AppTheme.warning),
              _MeterBand(start: 0.60, end: 0.70, color: AppTheme.destructive),
            ],
            currentColor: _whtrColor(whtr),
            leftLabel: 'Low risk',
            rightLabel: 'High risk',
            note: 'Target is below 0.50',
            currentLabel: whtr.toStringAsFixed(2),
          ),
        ),
      ],
    );
  }

  Widget _scoreCard({
    required String title,
    required IconData icon,
    required String value,
    String? unit,
    required Color valueColor,
    required Widget summary,
    required Widget child,
  }) {
    return ChartCard(
      title: title,
      showTitleBadge: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: valueColor),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Current',
                style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: valueColor,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      summary: Padding(padding: const EdgeInsets.only(top: 8), child: summary),
      child: child,
    );
  }

  Widget _metaPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.muted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meter({
    required double current,
    required double min,
    required double max,
    required List<_MeterBand> bands,
    required Color currentColor,
    required String leftLabel,
    required String rightLabel,
    required String note,
    required String currentLabel,
  }) {
    final safeMax = max <= min ? min + 1 : max;
    final clamped = current.clamp(min, safeMax).toDouble();
    final ratio = (clamped - min) / (safeMax - min);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final markerX = (ratio * constraints.maxWidth).clamp(
              4.0,
              constraints.maxWidth - 4.0,
            );

            const bubbleTextStyle = TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
            final textPainter = TextPainter(
              text: TextSpan(text: currentLabel, style: bubbleTextStyle),
              maxLines: 1,
              textDirection: Directionality.of(context),
            )..layout();

            final bubbleWidth = (textPainter.width + 16).clamp(56.0, 136.0);
            final bubbleMaxLeft = barWidth > bubbleWidth
                ? barWidth - bubbleWidth
                : 0.0;
            final bubbleLeft = (markerX - (bubbleWidth / 2)).clamp(
              0.0,
              bubbleMaxLeft,
            );

            const bubbleTop = 0.0;
            const barTop = 32.0;
            const barHeight = 12.0;
            const dotSize = 8.0;
            final dotTop = barTop + ((barHeight - dotSize) / 2);
            const lineTop = 24.0;
            final lineHeight = (dotTop - lineTop).clamp(6.0, 20.0);

            int bandFlex(_MeterBand band) {
              final span = (band.end - band.start).abs();
              final flex = (span * 1000).round();
              return flex > 0 ? flex : 1;
            }

            return SizedBox(
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: barTop,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppTheme.muted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            for (final band in bands)
                              Expanded(
                                flex: bandFlex(band),
                                child: Container(
                                  color: band.color.withValues(alpha: 0.28),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: bubbleLeft,
                    top: bubbleTop,
                    child: Container(
                      width: bubbleWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        currentLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: bubbleTextStyle.copyWith(color: currentColor),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerX - 1,
                    top: lineTop,
                    child: Container(
                      width: 2,
                      height: lineHeight,
                      decoration: BoxDecoration(
                        color: AppTheme.foreground.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerX - 4,
                    top: dotTop,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: const TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              rightLabel,
              style: const TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                note,
                style: const TextStyle(
                  color: AppTheme.mutedForeground,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeterBand {
  final double start;
  final double end;
  final Color color;

  const _MeterBand({
    required this.start,
    required this.end,
    required this.color,
  });
}
