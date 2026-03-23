import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/body_metric.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/unit_converter.dart';
import '../profile/profile_page.dart';
import 'widgets/body_metrics_section.dart';
import 'widgets/data_management_section.dart';
import 'widgets/about_section.dart';
import 'widgets/sign_out_button.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  UserProfile _profile = UserProfile();
  String _appVersion = '';

  // Body Metrics controllers
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _waistlineCtrl = TextEditingController();
  String _activityLevel = 'moderate';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVersion();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _waistlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(
        () => _appVersion = 'Version ${info.version}+${info.buildNumber}',
      );
    }
  }

  void _loadData() {
    if (!mounted) return;
    final storage = ref.read(storageProvider);
    final profile = storage.getUserProfile();
    final isMetric = (profile.unitSystem ?? 'metric') == 'metric';
    setState(() {
      _profile = profile;
      _weightCtrl.text = UnitConverter.weightToDisplay(profile.weight, isMetric: isMetric);
      _heightCtrl.text = UnitConverter.lengthToDisplay(profile.height, isMetric: isMetric);
      _waistlineCtrl.text = UnitConverter.lengthToDisplay(profile.waistline, isMetric: isMetric);
      _activityLevel = profile.activityLevel ?? 'moderate';
    });
  }

  // ─── Account Profile ─────────────────────────────────────────

  void _openProfilePage() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfilePage()))
        .then((_) => _loadData()); // refresh on return
  }

  // ─── Profile Nav Row ─────────────────────────────────────────

  Widget _buildProfileNavRow() {
    return GestureDetector(
      onTap: _openProfilePage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Body Metrics ────────────────────────────────────────────

  void _handleUpdateToday() {
    final storage = ref.read(storageProvider);
    final isMetric = (_profile.unitSystem ?? 'metric') == 'metric';
    final newWeight = UnitConverter.parseWeight(_weightCtrl.text, isMetric: isMetric);
    final newHeight = UnitConverter.parseLength(_heightCtrl.text, isMetric: isMetric);
    final newWaistline = UnitConverter.parseLength(_waistlineCtrl.text, isMetric: isMetric);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Update profile with latest body values
    final newProfile = _profile.copyWith(
      weight: newWeight ?? _profile.weight,
      height: newHeight ?? _profile.height,
      waistline: newWaistline ?? _profile.waistline,
      activityLevel: _activityLevel,
    );
    storage.setUserProfile(newProfile);

    // Save body metric for today
    storage.addBodyMetric(
      BodyMetric(date: todayStr, weight: newWeight, waistline: newWaistline),
    );

    setState(() => _profile = newProfile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Body metrics updated'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ─── Data Management ─────────────────────────────────────────

  void _handleClearData() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear Data'),
        content: const Text(
          'Are you sure you want to clear all meal data? This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(storageProvider).clearDemoData();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ─── Sign Out ────────────────────────────────────────────────

  Future<void> _handleSignOut() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(supabaseProvider).signOut();
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(storageProvider);
    return Column(
      children: [
        // Sticky Header
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Personalize your experience',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Account Profile — navigate to dedicated page
                  _buildProfileNavRow(),
                  const SizedBox(height: 24),
                  BodyMetricsSection(
                    weightCtrl: _weightCtrl,
                    heightCtrl: _heightCtrl,
                    waistlineCtrl: _waistlineCtrl,
                    activityLevel: _activityLevel,
                    onActivityChanged: (v) =>
                        setState(() => _activityLevel = v),
                    onUpdateToday: _handleUpdateToday,
                    isMetric: (_profile.unitSystem ?? 'metric') == 'metric',
                  ),
                  const SizedBox(height: 24),
                  DataManagementSection(onClearData: _handleClearData),
                  const SizedBox(height: 24),
                  AboutSection(appVersion: _appVersion),
                  const SizedBox(height: 24),
                  SignOutButton(onSignOut: _handleSignOut),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
