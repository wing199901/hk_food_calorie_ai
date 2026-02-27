import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'pages/landing_page.dart';
import 'pages/body_checkin_page.dart';
import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/analysis_page.dart';
import 'pages/log_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitCalorieApp());
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
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  late Future<StorageService> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initStorage();
  }

  Future<StorageService> _initStorage() async {
    final storage = StorageService();
    await storage.init();
    return storage;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StorageService>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        return AppShell(storage: snapshot.data!);
      },
    );
  }
}

/// Determines the initial route: Landing → BodyCheckin → MainScaffold.
class AppShell extends StatefulWidget {
  final StorageService storage;
  const AppShell({super.key, required this.storage});

  @override
  State<AppShell> createState() => _AppShellState();
}

enum AppScreen { landing, bodyCheckin, main }

class _AppShellState extends State<AppShell> {
  late AppScreen _screen;

  @override
  void initState() {
    super.initState();
    final profile = widget.storage.getUserProfile();
    final lastCheckin = widget.storage.getLastCheckinDate();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (profile.weight == null && profile.height == null) {
      _screen = AppScreen.landing;
    } else if (lastCheckin != today) {
      _screen = AppScreen.bodyCheckin;
    } else {
      _screen = AppScreen.main;
    }
  }

  void _goToCheckin() => setState(() => _screen = AppScreen.bodyCheckin);
  void _goToMain() => setState(() => _screen = AppScreen.main);

  @override
  Widget build(BuildContext context) {
    switch (_screen) {
      case AppScreen.landing:
        return LandingPage(onGetStarted: _goToCheckin);
      case AppScreen.bodyCheckin:
        return BodyCheckinPage(storage: widget.storage, onComplete: _goToMain);
      case AppScreen.main:
        return MainScaffold(storage: widget.storage);
    }
  }
}

/// Main app scaffold with bottom navigation.
class MainScaffold extends StatefulWidget {
  final StorageService storage;
  const MainScaffold({super.key, required this.storage});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime.now();

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void _onNavTap(int index) {
    if (index == 2) {
      // Center "+" button → Camera page as modal
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraPage(
            storage: widget.storage,
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
        storage: widget.storage,
        date: _selectedDate,
        setDate: _onDateChanged,
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
      AnalysisPage(storage: widget.storage),
      const SizedBox(), // placeholder for camera tab
      LogPage(
        storage: widget.storage,
        date: _selectedDate,
        setDate: _onDateChanged,
      ),
      SettingsPage(storage: widget.storage),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
