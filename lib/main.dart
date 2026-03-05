import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/providers/providers.dart';
import 'shared/services/storage_service.dart';
import 'shared/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/landing_page.dart';
import 'features/onboarding/complete_profile_page.dart';
import 'features/auth/auth_page.dart';
import 'features/check_in/check_in_page.dart';
import 'features/home/home_page.dart';
import 'features/food_analysis/add_food_page.dart';
import 'features/analysis/analysis_page.dart';
import 'features/log/log_page.dart';
import 'features/settings/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  // Pre-initialise StorageService so SharedPreferences is ready.
  final storage = StorageService();
  await storage.init();

  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWith((ref) => storage),
      ],
      child: const FitCalorieApp(),
    ),
  );
}

class FitCalorieApp extends StatelessWidget {
  const FitCalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitCalorie',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AppLoader(),
    );
  }
}

/// Loads StorageService async, then decides which screen to show.
class AppLoader extends ConsumerStatefulWidget {
  const AppLoader({super.key});

  @override
  ConsumerState<AppLoader> createState() => _AppLoaderState();
}

enum _Phase { loading, landing, auth, app }

class _AppLoaderState extends ConsumerState<AppLoader> {
  _Phase _phase = _Phase.loading;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final storage = ref.read(storageProvider);
    final supabase = ref.read(supabaseProvider);

    // React to future sign-in / sign-out events automatically.
    supabase.authStateChanges.listen((event) {
      if (!mounted) return;
      if (event.event == AuthChangeEvent.signedIn) {
        // Clear ALL local data (including stale guest/demo profile)
        // before pulling fresh cloud data for the authenticated user.
        storage.clearAllLocalData();
        storage.syncFromSupabase().then((_) {
          if (mounted) setState(() => _phase = _Phase.app);
        });
      } else if (event.event == AuthChangeEvent.signedOut) {
        setState(() => _phase = _Phase.landing);
      }
    });

    final isAuth = supabase.isAuthenticated;
    if (isAuth) {
      // Already logged in: sync first, then show app
      await storage.syncFromSupabase();
    }
    if (!mounted) return;
    setState(() {
      _phase = isAuth ? _Phase.app : _Phase.landing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageProvider);

    switch (_phase) {
      case _Phase.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );
      case _Phase.landing:
        return LandingPage(
          onGetStarted: () => setState(() => _phase = _Phase.auth),
        );
      case _Phase.auth:
        return AuthPage(
          onAuthenticated: () => setState(() => _phase = _Phase.app),
          onSkip: () {
            storage.initializeDemoData();
            setState(() => _phase = _Phase.app);
          },
        );
      case _Phase.app:
        return const AppShell();
    }
  }
}

/// Determines the initial route: Landing → BodyCheckIn → MainScaffold.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

enum AppScreen { completeProfile, bodyCheckIn, main }

class _AppShellState extends ConsumerState<AppShell> {
  late AppScreen _screen;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageProvider);
    final profile = storage.getUserProfile();
    final lastCheckIn = storage.getLastCheckInDate();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (!profile.isProfileComplete) {
      _screen = AppScreen.completeProfile;
    } else if (profile.weight == null && profile.height == null ||
        lastCheckIn != today) {
      _screen = AppScreen.bodyCheckIn;
    } else {
      _screen = AppScreen.main;
    }
  }

  void _onProfileComplete() {
    final storage = ref.read(storageProvider);
    final lastCheckIn = storage.getLastCheckInDate();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastCheckIn != today) {
      setState(() => _screen = AppScreen.bodyCheckIn);
    } else {
      setState(() => _screen = AppScreen.main);
    }
  }

  void _goToMain() => setState(() => _screen = AppScreen.main);

  @override
  Widget build(BuildContext context) {
    switch (_screen) {
      case AppScreen.completeProfile:
        return CompleteProfilePage(onComplete: _onProfileComplete);
      case AppScreen.bodyCheckIn:
        return CheckInPage(onComplete: _goToMain);
      case AppScreen.main:
        return const MainScaffold();
    }
  }
}

/// Main app scaffold with bottom navigation.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    if (index == 2) {
      // Center "+" button → Camera page as modal
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddFoodPage(
            onNavigate: (page) {
              Navigator.of(context).pop();
              if (page == 'home') setState(() => _currentIndex = 0);
              if (page == 'log') setState(() => _currentIndex = 3);
            },
          ),
        ),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onNavigate: (page) {
          if (page == 'camera') {
            _onNavTap(2);
          } else if (page == 'analysis') {
            setState(() => _currentIndex = 1);
          } else if (page == 'log') {
            setState(() => _currentIndex = 3);
          } else if (page == 'settings') {
            setState(() => _currentIndex = 4);
          }
        },
      ),
      const AnalysisPage(),
      const SizedBox(), // placeholder for camera tab
      const LogPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home, 'Home', 0),
                _navItem(Icons.bar_chart, 'Analysis', 1),
                _addButton(),
                _navItem(Icons.restaurant_menu, 'Log', 3),
                _navItem(Icons.settings, 'Settings', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => _onNavTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppTheme.primary : AppTheme.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.primary : AppTheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton() {
    return InkWell(
      onTap: () => _onNavTap(2),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x4010B981),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
