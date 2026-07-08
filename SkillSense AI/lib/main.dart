import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skillsense_ai/constants/app_colors.dart';
import 'package:skillsense_ai/services/auth_events.dart';
import 'package:skillsense_ai/services/auth_service.dart';

import 'screens/login/login_screen.dart';
import 'screens/welcome/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set the status bar style to match the light background
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const SkillSenseApp());
}

/// Global navigator key — used by [AuthEvents] force-logout to navigate
/// without a [BuildContext].
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SkillSenseApp extends StatefulWidget {
  const SkillSenseApp({super.key});

  @override
  State<SkillSenseApp> createState() => _SkillSenseAppState();
}

class _SkillSenseAppState extends State<SkillSenseApp> {
  late final StreamSubscription<void> _logoutSub;

  @override
  void initState() {
    super.initState();

    // Listen for forced-logout events fired by the AuthInterceptor
    // when a refresh token is rejected / expired.
    _logoutSub = AuthEvents.onForceLogout.listen((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _logoutSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillSense AI',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // Start with a splash / auth-check screen
      home: const _AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        // TODO: Add '/dashboard' route once dashboard screen exists
      },
    );
  }
}

/// Checks for an existing valid session on app launch.
///
/// - If a valid session exists (access token present or silently refreshed via
///   the httpOnly cookie), navigates straight to the dashboard.
/// - Otherwise, shows the welcome / login screen.
///
/// On web, the first call to [AuthService.fetchCurrentUser] will 401 (no
/// in-memory access token after page reload), the [AuthInterceptor] will
/// silently refresh using the browser's httpOnly cookie, and the retried
/// request will succeed — all before this widget finishes loading.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = await AuthService.fetchCurrentUser();
    if (!mounted) return;

    if (user != null) {
      // User has a valid session — go to the dashboard.
      // TODO: Replace with Navigator.pushReplacementNamed('/dashboard')
      // once the dashboard screen is wired up. For now, go to welcome.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else {
      // No valid session — show the welcome / login flow.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple loading indicator while the auth check runs.
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
