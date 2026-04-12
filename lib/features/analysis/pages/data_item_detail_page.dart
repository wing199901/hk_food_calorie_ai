import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

class DataItemDetailPage extends ConsumerStatefulWidget {
  final String valueLabel;
  final String value;
  final String dateText;
  final String dateAddedText;
  final bool isUserEntered;

  const DataItemDetailPage({
    super.key,
    required this.valueLabel,
    required this.value,
    required this.dateText,
    required this.dateAddedText,
    required this.isUserEntered,
  });

  @override
  ConsumerState<DataItemDetailPage> createState() => _DataItemDetailPageState();
}

class _DataItemDetailPageState extends ConsumerState<DataItemDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('data_item_detail_scaffold'),
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppTheme.foreground,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sample Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foreground,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                key: const Key('data_item_detail_card'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _detailRow(
                      label: widget.valueLabel,
                      value: widget.value,
                      isLast: false,
                    ),
                    _detailRow(
                      label: 'Date',
                      value: widget.dateText,
                      isLast: false,
                    ),
                    _detailRow(
                      label: 'Date Added',
                      value: widget.dateAddedText,
                      isLast: false,
                    ),
                    _detailRow(
                      label: 'Was User Entered',
                      value: widget.isUserEntered ? 'Yes' : 'No',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
