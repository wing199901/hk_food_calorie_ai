import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

class AiInsightSection extends StatefulWidget {
  final String focus;
  final String period;

  const AiInsightSection({
    super.key,
    required this.focus,
    this.period = 'week',
  });

  @override
  State<AiInsightSection> createState() => _AiInsightSectionState();
}

class _AiInsightSectionState extends State<AiInsightSection> {
  bool _hasTriggered = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _report;

  Future<void> _fetchInsight() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'generate-ai-insight',
        body: {

          'period': widget.period,
          'focus': widget.focus,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data['success'] == true) {
          setState(() {
            _report = data['report'];
            _isLoading = false;
          });
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception('Failed to load insights (${response.status})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('ai_insight_${widget.focus}'),
      onVisibilityChanged: (info) {
        if (!_hasTriggered && info.visibleFraction >= 0.75) {
          _hasTriggered = true;
          _fetchInsight();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              'Insights & Tips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
            ),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_report != null) {
      final summary = _report!['summary'] as String?;
      final analysis = _report!['analysis'] as String?;
      final trends = (_report!['trends'] as List?)?.cast<String>();
      final recs = (_report!['recommendations'] as List?)?.cast<String>();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('AI Summary'),
          Text(summary ?? '', style: _textStyle),
          if (analysis != null) ...[
            const SizedBox(height: 12),
            _sectionTitle('Analysis'),
            Text(analysis, style: _textStyle),
          ],
          if (trends != null && trends.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle('Trends'),
            ...trends.map((t) => _bulletPoint(t)),
          ],
          if (recs != null && recs.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle('Recommendations'),
            ...recs.map((r) => _bulletPoint(r)),
          ],
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.warning, size: 32),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppTheme.warning)),
          TextButton(
            onPressed: () {
              _hasTriggered = false;
              _fetchInsight();
            },
            child: const Text('Try Again'),
          )
        ],
      );
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              SizedBox(height: 16),
              Text(
                'AI 正在分析數據...',
                style: TextStyle(
                  color: AppTheme.mutedForeground,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildSkeleton();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
  }

  final _textStyle = const TextStyle(
    fontSize: 14,
    color: AppTheme.foreground,
    letterSpacing: -0.2,
    height: 1.4,
  );

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: _textStyle)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonBox(width: 150, height: 16),
        const SizedBox(height: 12),
        _skeletonBox(width: double.infinity, height: 14),
        const SizedBox(height: 6),
        _skeletonBox(width: double.infinity, height: 14),
        const SizedBox(height: 6),
        _skeletonBox(width: 200, height: 14),
        const SizedBox(height: 16),
        _skeletonBox(width: 120, height: 16),
        const SizedBox(height: 12),
        _skeletonBox(width: double.infinity, height: 14),
        const SizedBox(height: 6),
        _skeletonBox(width: 180, height: 14),
      ],
    );
  }

  Widget _skeletonBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}