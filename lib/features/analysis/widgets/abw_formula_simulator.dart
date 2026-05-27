import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../shared/services/storage_service.dart';
import 'detail_text_card.dart';

/// Interactive simulator that shows when ABW replaces actual weight.
class AbwFormulaSimulatorCard extends StatefulWidget {
  final double? heightCm;
  final String? gender;
  final String? unitSystem;
  final double? initialWeightKg;

  const AbwFormulaSimulatorCard({
    super.key,
    required this.heightCm,
    required this.gender,
    required this.unitSystem,
    required this.initialWeightKg,
  });

  @override
  State<AbwFormulaSimulatorCard> createState() =>
      _AbwFormulaSimulatorCardState();
}

class _AbwFormulaSimulatorCardState extends State<AbwFormulaSimulatorCard> {
  late double _displayWeight;
  late double _minDisplay;
  late double _maxDisplay;
  double? _ibwKg;
  Timer? _switchHintTimer;
  bool _showSwitchHint = false;
  bool _useAbwLast = false;

  bool get _isMetric => widget.unitSystem != 'imperial';

  @override
  void initState() {
    super.initState();
    _resetRange();
  }

  @override
  void didUpdateWidget(covariant AbwFormulaSimulatorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heightCm != widget.heightCm ||
        oldWidget.gender != widget.gender ||
        oldWidget.unitSystem != widget.unitSystem ||
        oldWidget.initialWeightKg != widget.initialWeightKg) {
      _resetRange();
    }
  }

  void _resetRange() {
    final ibwKg = StorageService.calculateDevineIbwKg(
      heightCm: widget.heightCm,
      gender: widget.gender,
    );
    _ibwKg = ibwKg;

    final baseKg = widget.initialWeightKg ?? ibwKg ?? 70.0;
    final minKg = math.max(35.0, (ibwKg ?? baseKg) * 0.6);
    final maxKg = math.max(minKg + 20.0, (ibwKg ?? baseKg) * 1.6);

    _minDisplay = _toDisplay(minKg);
    _maxDisplay = _toDisplay(maxKg);

    final initialDisplay = _toDisplay(baseKg);
    _displayWeight = initialDisplay
        .clamp(_minDisplay, _maxDisplay)
        .toDouble();

    _switchHintTimer?.cancel();
    _showSwitchHint = false;
    if (ibwKg != null && ibwKg > 0) {
      _useAbwLast = _toKg(_displayWeight) > ibwKg * 1.2;
    } else {
      _useAbwLast = false;
    }
  }

  void _startSwitchHintTimer() {
    _switchHintTimer?.cancel();
    _switchHintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _showSwitchHint = false;
      });
    });
  }

  double _toDisplay(double kg) =>
      _isMetric ? kg : UnitConverter.kgToLbs(kg);

  double _toKg(double display) =>
      _isMetric ? display : UnitConverter.lbsToKg(display);

  String _formatWeight(double? kg) =>
      UnitConverter.formatWeight(kg, isMetric: _isMetric);

  String _formatNumber(double value) => value.toStringAsFixed(1);

  @override
  void dispose() {
    _switchHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ibwKg = _ibwKg;
    final hasIbw = ibwKg != null && ibwKg > 0;

    return DetailTextCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Formula Simulator',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Move the slider to see when ABW is used for energy targets.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.foreground,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!hasIbw)
            const Text(
              'Add your height in profile settings to unlock this simulator.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedForeground,
              ),
            )
          else
            _buildSimulatorContent(ibwKg),
        ],
      ),
    );
  }

  Widget _buildSimulatorContent(double ibwKg) {
    final actualKg = _toKg(_displayWeight);
    final thresholdKg = ibwKg * 1.2;
    final useAbw = actualKg > thresholdKg;
    final abwKg = ibwKg + 0.4 * (actualKg - ibwKg);
    final teeWeightKg = useAbw ? abwKg : actualKg;

    final actualDisplay = _toDisplay(actualKg);
    final ibwDisplay = _toDisplay(ibwKg);
    final abwDisplay = _toDisplay(abwKg);
    final unitLabel = _isMetric ? 'kg' : 'lbs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _statChip('Actual', _formatWeight(actualKg)),
            _statChip('IBW', _formatWeight(ibwKg)),
            _statChip('120% IBW', _formatWeight(thresholdKg)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.muted,
            thumbColor: AppTheme.primary,
            overlayColor: AppTheme.primary.withValues(alpha: 0.14),
            trackHeight: 6,
            padding: EdgeInsets.zero,
          ),
          child: Slider(
            key: const Key('abw_weight_slider'),
            value: _displayWeight,
            min: _minDisplay,
            max: _maxDisplay,
            onChanged: (value) {
              final nextDisplay = value
                  .clamp(_minDisplay, _maxDisplay)
                  .toDouble();
              final nextUseAbw = _toKg(nextDisplay) > thresholdKg;
              final shouldShowHint = nextUseAbw && !_useAbwLast;
              setState(() {
                _displayWeight = nextDisplay;
                _useAbwLast = nextUseAbw;
                if (shouldShowHint) {
                  _showSwitchHint = true;
                }
              });
              if (shouldShowHint) {
                _startSwitchHintTimer();
              }
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _sourcePill(
                    label: 'IBW',
                    color: AppTheme.primary,
                    isActive: !useAbw,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _sourcePill(
                    label: 'ABW',
                    color: AppTheme.accent,
                    isActive: useAbw,
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showSwitchHint
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Switching to ABW for accuracy',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Text(
                    'TEE weight source: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.foreground,
                    ),
                  ),
                  Text(
                    useAbw ? 'ABW' : 'Actual',
                    key: const Key('abw_source_value'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: useAbw ? AppTheme.accent : AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Weight used for TEE: ${_formatWeight(teeWeightKg)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.foreground,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: 'ABW = '),
                    TextSpan(
                      text: _formatNumber(ibwDisplay),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: useAbw ? AppTheme.accent : AppTheme.primary,
                      ),
                    ),
                    const TextSpan(text: ' + 0.4 x ('),
                    TextSpan(
                      text: _formatNumber(actualDisplay),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const TextSpan(text: ' - '),
                    TextSpan(
                      text: _formatNumber(ibwDisplay),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const TextSpan(text: ') = '),
                    TextSpan(
                      text: '${_formatNumber(abwDisplay)} $unitLabel',
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
      ],
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourcePill({
    required String label,
    required Color color,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.45 : 0.2),
        ),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isActive ? color : AppTheme.mutedForeground,
        ),
        child: Text(label),
      ),
    );
  }
}
