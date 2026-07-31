import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skillsense_ai/constants/app_colors.dart';
import 'package:skillsense_ai/services/auth_events.dart';
import 'package:skillsense_ai/services/auth_service.dart';

import 'screens/login/login_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/dashboard/command_deck_screen.dart';
import 'screens/hr/hr_pipeline_screen.dart';
import 'screens/hr/candidate_report_screen.dart';
import 'screens/hr/live_monitor_screen.dart';
import 'screens/hr/create_role_screen.dart';
import 'screens/hr/schedule_interview_screen.dart';
import 'screens/hr/rankings_screen.dart';
import 'screens/hr/analytics_screen.dart';
import 'screens/hr/interview_review_screen.dart';
import 'screens/hr/settings_screen.dart';
import 'screens/hr/org_team_screen.dart';
import 'screens/candidate/candidate_home_screen.dart';
import 'screens/candidate/candidate_applications_screen.dart';
import 'screens/candidate/candidate_job_feed_screen.dart';
import 'screens/candidate/candidate_job_detail_screen.dart';
import 'screens/candidate/candidate_interview_lobby_screen.dart';
import 'screens/candidate/candidate_interview_session_screen.dart';
import 'screens/candidate/candidate_feedback_report_screen.dart';
import 'screens/candidate/candidate_resume_management_screen.dart';
import 'screens/candidate/candidate_interview_history_screen.dart';
import 'screens/candidate/candidate_profile_settings_screen.dart';
import 'screens/welcome/aperture_splash_screen.dart';

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
      home: const ApertureSplashScreen(),
      onGenerateRoute: (settings) {
        Widget builder;
        switch (settings.name) {
          case '/login':
            builder = const LoginScreen();
            break;
          case '/welcome':
            builder = const WelcomeScreen();
            break;
          case '/dashboard':
            builder = const CommandDeckScreen();
            break;
          case '/pipeline':
            builder = const HrPipelineScreen();
            break;
          case '/report':
            builder = const CandidateReportScreen();
            break;
          case '/monitor':
            builder = const LiveMonitorScreen();
            break;
          case '/create-role':
            builder = const CreateRoleScreen();
            break;
          case '/schedule':
            builder = const ScheduleInterviewScreen();
            break;
          case '/rankings':
            builder = const RankingsScreen();
            break;
          case '/analytics':
            builder = const AnalyticsScreen();
            break;
          case '/review':
            builder = const InterviewReviewScreen();
            break;
          case '/settings':
            builder = const SettingsScreen();
            break;
          case '/org':
            builder = const OrgTeamScreen();
            break;
          case '/candidate/home':
            builder = const CandidateHomeScreen();
            break;
          case '/candidate/applications':
            builder = const CandidateApplicationsScreen();
            break;
          case '/candidate/jobs':
            builder = const CandidateJobFeedScreen();
            break;
          case '/candidate/job-detail':
            builder = const CandidateJobDetailScreen();
            break;
          case '/candidate/interview-lobby':
            builder = const CandidateInterviewLobbyScreen();
            break;
          case '/candidate/interview-session':
            builder = const CandidateInterviewSessionScreen();
            break;
          case '/candidate/feedback-report':
            builder = const CandidateFeedbackReportScreen();
            break;
          case '/candidate/resumes':
            builder = const CandidateResumeManagementScreen();
            break;
          case '/candidate/interviews':
            builder = const CandidateInterviewHistoryScreen();
            break;
          case '/candidate/profile':
            builder = const CandidateProfileSettingsScreen();
            break;
          default:
            builder = const _AuthGate();
        }
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => builder,
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
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
      Navigator.of(context).pushReplacementNamed('/dashboard');
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
