import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/body_metric.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class CheckInPage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const CheckInPage({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends ConsumerState<CheckInPage> {
  final _weightController = TextEditingController();
  final _waistlineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(storageProvider).getUserProfile();
    if (profile.weight != null) {
      _weightController.text = profile.weight.toString();
    }
    if (profile.waistline != null) {
      _waistlineController.text = profile.waistline.toString();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _waistlineController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final storage = ref.read(storageProvider);
    final newWeight = double.tryParse(_weightController.text);
    final newWaistline = double.tryParse(_waistlineController.text);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    storage.addBodyMetric(
      BodyMetric(date: todayStr, weight: newWeight, waistline: newWaistline),
    );

    final profile = storage.getUserProfile();
    storage.setUserProfile(
      profile.copyWith(
        weight: newWeight ?? profile.weight,
        waistline: newWaistline ?? profile.waistline,
      ),
    );
    storage.setLastCheckInDate(todayStr);
    widget.onComplete();
  }

  void _handleSkip() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.read(storageProvider).setLastCheckInDate(todayStr);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Daily Check-in',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track your progress to stay on target.',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildInputField(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Current Weight (kg)',
                    controller: _weightController,
                    hint: '70.5',
                  ),
                  const SizedBox(height: 24),
                  _buildInputField(
                    icon: Icons.straighten,
                    label: 'Waistline (cm)',
                    controller: _waistlineController,
                    hint: '80',
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Save & Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _handleSkip,
                    child: const Text(
                      'Skip for today',
                      style: TextStyle(
                        color: AppTheme.mutedForeground,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.mutedForeground),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}
