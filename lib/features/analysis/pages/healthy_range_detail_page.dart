import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/unit_converter.dart';
import '../widgets/detail_text_card.dart';

({
  bool isMetric,
  String weightUnit,
  String heightText,
  String lowerText,
  String upperText,
  String lowerFormula,
  String upperFormula,
  String overweightFormula,
  String genderConstantText,
  double lowerDisplay,
  double upperDisplay,
  double overweightDisplay,
  double? currentDisplay,
})
_buildRangeFormulaData({
  required double? heightCm,
  required double lowerKg,
  required double upperKg,
  required String? gender,
  required String? unitSystem,
  required double? currentWeightKg,
}) {
  final isMetric = unitSystem != 'imperial';
  final weightUnit = isMetric ? 'kg' : 'lbs';

  final heightM = (heightCm != null && heightCm > 0) ? heightCm / 100.0 : null;
  final heightIn = (heightCm != null && heightCm > 0)
      ? UnitConverter.cmToIn(heightCm)
      : null;

  final lowerDisplay = isMetric ? lowerKg : UnitConverter.kgToLbs(lowerKg);
  final upperDisplay = isMetric ? upperKg : UnitConverter.kgToLbs(upperKg);
  final overweightDisplay = isMetric
      ? 25.0 * (heightM != null ? heightM * heightM : 1.0)
      : UnitConverter.kgToLbs(
          25.0 * (heightM != null ? heightM * heightM : 1.0),
        );
  final currentDisplay = currentWeightKg == null
      ? null
      : (isMetric ? currentWeightKg : UnitConverter.kgToLbs(currentWeightKg));

  final heightText = heightCm == null
      ? '--'
      : (isMetric
            ? '${heightCm.toStringAsFixed(0)} cm'
            : '${UnitConverter.cmToIn(heightCm).toStringAsFixed(1)} in');

  final lowerFormula = heightM == null || heightIn == null
      ? '18.5 BMI x height^2'
      : (isMetric
            ? '18.5 BMI x (${heightM.toStringAsFixed(2)} m ^ 2) = ${lowerDisplay.toStringAsFixed(1)} kg'
            : '18.5 BMI x (${heightIn.toStringAsFixed(1)} in ^ 2) / 703 = ${lowerDisplay.toStringAsFixed(1)} lbs');

  final genderConstantKg = gender == 'female' ? 45.5 : 50.0;
  final genderConstantLbs = gender == 'female' ? 100.3 : 110.2;

  final upperFormula = heightIn == null || heightCm == null
      ? '${genderConstantKg.toStringAsFixed(1)} kg + 2.3 kg x ((height_cm - 152.4 cm) / 2.54)'
      : (isMetric
            ? '${genderConstantKg.toStringAsFixed(1)} kg + 2.3 kg x ((${heightCm.toStringAsFixed(1)} cm - 152.4 cm) / 2.54) = ${upperDisplay.toStringAsFixed(1)} kg'
            : '${genderConstantLbs.toStringAsFixed(1)} lbs + 5.07 lbs x (${heightIn.toStringAsFixed(1)} in - 60) = ${upperDisplay.toStringAsFixed(1)} lbs');

  final overweightFormula = heightM == null || heightIn == null
      ? '25 BMI x height^2'
      : (isMetric
            ? '25 BMI x (${heightM.toStringAsFixed(2)} m ^ 2) = ${overweightDisplay.toStringAsFixed(1)} kg'
            : '25 BMI x (${heightIn.toStringAsFixed(1)} in ^ 2) / 703 = ${overweightDisplay.toStringAsFixed(1)} lbs');

  final genderConstantText = isMetric
      ? 'Gender constant: 50.0 kg (male) / 45.5 kg (female).'
      : 'Gender constant: 110.2 lbs (male) / 100.3 lbs (female).';

  return (
    isMetric: isMetric,
    weightUnit: weightUnit,
    heightText: heightText,
    lowerText: '${lowerDisplay.toStringAsFixed(1)} $weightUnit',
    upperText: '${upperDisplay.toStringAsFixed(1)} $weightUnit',
    lowerFormula: lowerFormula,
    upperFormula: upperFormula,
    overweightFormula: overweightFormula,
    genderConstantText: genderConstantText,
    lowerDisplay: lowerDisplay,
    upperDisplay: upperDisplay,
    overweightDisplay: overweightDisplay,
    currentDisplay: currentDisplay,
  );
}

class HealthyRangeDetailPage extends StatelessWidget {
  final double? currentWeightKg;
  final double? heightCm;
  final double? lowerKg;
  final double? upperKg;
  final String? gender;
  final String? unitSystem;

  const HealthyRangeDetailPage({
    super.key,
    required this.currentWeightKg,
    required this.heightCm,
    required this.lowerKg,
    required this.upperKg,
    required this.gender,
    required this.unitSystem,
  });

  @override
  Widget build(BuildContext context) {
    final minimumThreshold = lowerKg ?? 56.7;
    final idealWeight = upperKg ?? 70.5;
    final formulaData = _buildRangeFormulaData(
      heightCm: heightCm,
      lowerKg: minimumThreshold,
      upperKg: idealWeight,
      gender: gender,
      unitSystem: unitSystem,
      currentWeightKg: currentWeightKg,
    );
    final hText = formulaData.heightText;
    final lowText = formulaData.lowerText;
    final upText = formulaData.upperText;
    final lowerFormula = formulaData.lowerFormula;
    final upperFormula = formulaData.upperFormula;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: const Text(
          'How Your Weight Range Is Calculated',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
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
                  Text(
                    'For height $hText, your healthy growth range is $lowText to $upText.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'BMI 18.5 is the minimum healthy threshold. Below it, you are still in the underweight range; above it, your body has a better reserve for energy, immunity, and recovery.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.foreground,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _benefitChip(
                        icon: Icons.shield_outlined,
                        label: 'Immunity',
                      ),
                      _benefitChip(
                        icon: Icons.battery_full,
                        label: 'Energy reserve',
                      ),
                    ],
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
                        const TextSpan(text: 'Minimum threshold = '),
                        TextSpan(
                          text: lowerFormula,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '\nMeaning: BMI 18.5 is the minimum healthy threshold. Below this point, you are still considered underweight.\n\nIdeal target = ',
                        ),
                        TextSpan(
                          text: upperFormula,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '\nMeaning: this is the Devine IBW target, where body load is usually light and the balance is medically favorable.\n\nSummary: ',
                        ),
                        TextSpan(
                          text:
                              'your healthy weight range is $lowText - $upText.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DetailTextCard(
              child: WeightZoneScale(
                minimumThresholdKg: lowerKg,
                idealWeightKg: upperKg,
                currentWeightKg: currentWeightKg,
                heightCm: heightCm,
                gender: gender,
                unitSystem: unitSystem,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppTheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class WeightZoneScale extends StatefulWidget {
  final double? minimumThresholdKg;
  final double? idealWeightKg;
  final double? currentWeightKg;
  final double? heightCm;
  final String? gender;
  final String? unitSystem;

  const WeightZoneScale({
    super.key,
    required this.minimumThresholdKg,
    required this.idealWeightKg,
    required this.currentWeightKg,
    required this.heightCm,
    required this.gender,
    required this.unitSystem,
  });

  @override
  State<WeightZoneScale> createState() => _WeightZoneScaleState();
}

class _WeightZoneScaleState extends State<WeightZoneScale> {
  late double _simulatedWeightKg;

  double get _minimumThreshold => widget.minimumThresholdKg ?? 0;
  double get _idealWeight => widget.idealWeightKg ?? 0;

  double get _bmi25Threshold {
    final h = widget.heightCm;
    if (h == null || h <= 0) return _minimumThreshold + 8.0;
    final hM = h / 100;
    return math.max(_minimumThreshold + 0.1, 25 * hM * hM);
  }

  double get _scaleMin =>
      math.max(35.0, math.min(_minimumThreshold, _bmi25Threshold) - 16.0);

  double get _scaleMax {
    final ceiling = math.max(_idealWeight, _bmi25Threshold);
    return math.max(_scaleMin + 34.0, ceiling + 10.0);
  }

  double _clampWeight(double value) {
    return value.clamp(_scaleMin, _scaleMax).toDouble();
  }

  double _initialWeight() {
    final fallback = (_minimumThreshold + _idealWeight) / 2;
    return _clampWeight(widget.currentWeightKg ?? fallback);
  }

  @override
  void initState() {
    super.initState();
    _simulatedWeightKg = _initialWeight();
  }

  @override
  void didUpdateWidget(covariant WeightZoneScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasFollowingCurrent =
        oldWidget.currentWeightKg != null &&
        (_simulatedWeightKg - oldWidget.currentWeightKg!).abs() < 0.01;
    if (wasFollowingCurrent && widget.currentWeightKg != null) {
      _simulatedWeightKg = _clampWeight(widget.currentWeightKg!);
      return;
    }
    _simulatedWeightKg = _clampWeight(_simulatedWeightKg);
  }

  double? _bmiFor(double weightKg) {
    final h = widget.heightCm;
    if (h == null || h <= 0) return null;
    final hM = h / 100;
    return weightKg / (hM * hM);
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppTheme.destructive;
    if (bmi < 25) return AppTheme.primary;
    if (bmi < 30) return AppTheme.accent;
    return AppTheme.warning;
  }

  double _positionForWeight({required double weight, required double width}) {
    final w = _clampWeight(weight);
    final oneThird = width / 3;
    final twoThird = oneThird * 2;

    if (w <= _minimumThreshold) {
      final span = math.max(_minimumThreshold - _scaleMin, 0.001);
      final t = (w - _scaleMin) / span;
      return t * oneThird;
    }

    if (w <= _bmi25Threshold) {
      final span = math.max(_bmi25Threshold - _minimumThreshold, 0.001);
      final t = (w - _minimumThreshold) / span;
      return oneThird + t * oneThird;
    }

    final span = math.max(_scaleMax - _bmi25Threshold, 0.001);
    final t = (w - _bmi25Threshold) / span;
    return twoThird + t * oneThird;
  }

  double _safeIdealMarkerX({
    required double idealX,
    required double bmiX,
    required double scaleWidth,
  }) {
    const minGap = 22.0;
    if ((idealX - bmiX).abs() >= minGap) return idealX;
    final shifted = idealX > bmiX ? bmiX + minGap : bmiX - minGap;
    return shifted.clamp(0.0, scaleWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _bmiFor(_simulatedWeightKg);
    final bmiText = bmi != null ? bmi.toStringAsFixed(1) : '--';
    final bmiStatusColor = bmi != null
        ? _bmiColor(bmi)
        : AppTheme.mutedForeground;

    final formulaData = _buildRangeFormulaData(
      heightCm: widget.heightCm,
      lowerKg: _minimumThreshold,
      upperKg: _idealWeight,
      gender: widget.gender,
      unitSystem: widget.unitSystem,
      currentWeightKg: _simulatedWeightKg,
    );
    final lowerFormula = formulaData.lowerFormula;
    final upperFormula = formulaData.upperFormula;
    final overweightFormula = formulaData.overweightFormula;
    final currentDisplay = formulaData.currentDisplay;
    final weightUnit = formulaData.weightUnit;
    final lowerValueText =
        '${formulaData.lowerDisplay.toStringAsFixed(1)} $weightUnit';
    final idealValueText =
        '${formulaData.upperDisplay.toStringAsFixed(1)} $weightUnit';

    const underZoneColor = Color.fromARGB(116, 255, 107, 107);
    const normalZoneColor = Color.fromARGB(121, 16, 185, 129);
    const overZoneColor = Color.fromARGB(124, 255, 139, 61);

    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        const scaleHorizontalPadding = 8.0;
        final scaleWidth = math.max(0.0, width - (scaleHorizontalPadding * 2));

        final oneThird = scaleWidth / 3;
        final minimumX = oneThird;

        final bmi25X = _positionForWeight(
          weight: _bmi25Threshold,
          width: scaleWidth,
        );
        final currentX = _positionForWeight(
          weight: _simulatedWeightKg,
          width: scaleWidth,
        );
        final idealX = _safeIdealMarkerX(
          idealX: _positionForWeight(weight: _idealWeight, width: scaleWidth),
          bmiX: bmi25X,
          scaleWidth: scaleWidth,
        );
        const markerWidth = 112.0;
        // Reduced chartTop to tighten gap between the big title/badge and chart
        const chartTop = 96.0;
        const chartHeight = 20.0;
        const markerBaseTop = chartTop - 40;
        final currentMarkerTop = markerBaseTop;
        const minimumMarkerTop = markerBaseTop;
        const idealMarkerTop = markerBaseTop;

        Widget marker({
          required double x,
          required double top,
          required String title,
          required String value,
          required Color color,
          double markerBoxWidth = markerWidth,
          bool keepCenter = false,
          bool isCurrent = false,
        }) {
          final desiredLeft = x + scaleHorizontalPadding - markerBoxWidth / 2;
          final left = keepCenter
              ? desiredLeft
              : desiredLeft
                    .clamp(
                      0.0,
                      markerBoxWidth > 0 ? width - markerBoxWidth : 0.0,
                    )
                    .toDouble();
          final markerTop = isCurrent ? top - 36 : top;
          return Positioned(
            left: left,
            top: markerTop,
            width: markerBoxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          );
        }

        Widget verticalIndicator({
          required Key markerKey,
          required double x,
          required Color color,
        }) {
          final lineWidth = 3.0;
          final indicatorHeight =
              (markerKey == const Key('marker_line_current')) ? 56.0 : 32.0;
          return Positioned(
            key: markerKey,
            left: x + scaleHorizontalPadding - (lineWidth / 2),
            top: chartTop + (chartHeight - indicatorHeight) / 2,
            child: CustomPaint(
              size: Size(lineWidth, indicatorHeight),
              painter: _DottedVerticalLinePainter(
                color: color,
                lineWidth: lineWidth,
              ),
            ),
          );
        }

        final bmiBadge = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.min(220.0, width * 0.5)),
          child: AnimatedContainer(
            key: const Key('weight_bmi_badge'),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bmiStatusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: bmiStatusColor,
              ),
              child: Text(
                'BMI $bmiText',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weight',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              key: const Key('weight_header_row'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  key: const Key('weight_value_text'),
                  currentDisplay != null
                      ? '${currentDisplay.toStringAsFixed(1)} $weightUnit'
                      : '-- $weightUnit',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.foreground,
                    height: 1,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: bmiBadge,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Drag the slider to preview where your weight lands on the zone bar.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.mutedForeground,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SizedBox(
              height: 176,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  marker(
                    x: currentX,
                    top: currentMarkerTop,
                    title: 'Current',
                    value: currentDisplay != null
                        ? '${currentDisplay.toStringAsFixed(1)} $weightUnit'
                        : '-- $weightUnit',
                    color: AppTheme.foreground,
                    keepCenter: true,
                    isCurrent: true,
                  ),
                  marker(
                    x: minimumX,
                    top: minimumMarkerTop,
                    title: 'Minimum',
                    value: lowerValueText,
                    color: AppTheme.primary,
                  ),
                  marker(
                    x: idealX,
                    top: idealMarkerTop,
                    title: 'Ideal',
                    value: idealValueText,
                    color: AppTheme.chartWeight,
                  ),
                  Positioned(
                    top: chartTop,
                    left: scaleHorizontalPadding,
                    width: scaleWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        key: const Key('weight_zone_bar'),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              underZoneColor,
                              underZoneColor,
                              normalZoneColor,
                              normalZoneColor,
                              overZoneColor,
                              overZoneColor,
                            ],
                            stops: [
                              0.0,
                              0.333333,
                              0.333333,
                              0.666666,
                              0.666666,
                              1.0,
                            ],
                          ),
                        ),
                        height: chartHeight,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  verticalIndicator(
                    markerKey: const Key('marker_line_current'),
                    x: currentX,
                    color: AppTheme.foreground,
                  ),
                  verticalIndicator(
                    markerKey: const Key('marker_line_minimum'),
                    x: minimumX,
                    color: AppTheme.primary,
                  ),
                  verticalIndicator(
                    markerKey: const Key('marker_line_ideal'),
                    x: idealX,
                    color: AppTheme.chartWeight,
                  ),
                  Positioned(
                    top: chartTop + chartHeight + AppSpacing.sm,
                    left: scaleHorizontalPadding,
                    width: scaleWidth,
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Underweight',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.destructive,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Normal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Overweight',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: scaleHorizontalPadding,
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: AppTheme.muted,
                  thumbColor: AppTheme.primary,
                  overlayColor: AppTheme.primary.withValues(alpha: 0.14),
                  trackHeight: 6,
                  padding: EdgeInsets.zero,
                ),
                child: Slider(
                  value: _simulatedWeightKg,
                  min: _scaleMin,
                  max: _scaleMax,
                  onChanged: (value) {
                    setState(() {
                      _simulatedWeightKg = _clampWeight(value);
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  iconColor: AppTheme.primary,
                  collapsedIconColor: AppTheme.primary,
                  title: const Text(
                    'Calculation Formula',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                    ),
                  ),
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.foreground,
                          height: 1.45,
                        ),
                        children: [
                          const TextSpan(text: 'Minimum threshold: '),
                          TextSpan(
                            text: '$lowerFormula\n',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: 'Ideal weight: '),
                          TextSpan(
                            text: '$upperFormula\n',
                            style: const TextStyle(
                              color: AppTheme.chartWeight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: 'Overweight formula: '),
                          TextSpan(
                            text: '$overweightFormula\n',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DottedVerticalLinePainter extends CustomPainter {
  final Color color;
  final double lineWidth;

  const _DottedVerticalLinePainter({
    required this.color,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final radius = math.max(0.8, lineWidth / 2);
    final centerX = size.width / 2;
    for (double y = 0; y <= size.height; y += 4.0) {
      canvas.drawCircle(Offset(centerX, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedVerticalLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.lineWidth != lineWidth;
  }
}
