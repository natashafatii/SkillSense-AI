import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skillsense_ai/constants/app_colors.dart';
import 'package:skillsense_ai/constants/env_config.dart';

// Conditional import: picks the web or native platform integration.
import 'services/platform_app_stub.dart'
    if (dart.library.js_interop) 'services/platform_app_web.dart'
    if (dart.library.io) 'services/platform_app_native.dart';

import 'screens/login/login_screen.dart';
import 'screens/login/role_selection_screen.dart' as login_role;
import 'screens/signup/signup_role_selection_screen.dart';
import 'screens/signup/candidate_register_screen.dart';
import 'screens/signup/hr_register_screen.dart';
import 'screens/candidate/candidate_onboarding_flow.dart';
import 'screens/hr/hr_onboarding_flow.dart';
import 'screens/candidate/candidate_applications_screen.dart';
import 'screens/candidate/candidate_feedback_report_screen.dart';
import 'screens/candidate/candidate_home_screen.dart';
import 'screens/candidate/candidate_interview_history_screen.dart';
import 'screens/candidate/candidate_interview_lobby_screen.dart';
import 'screens/candidate/candidate_interview_session_screen.dart';
import 'screens/candidate/candidate_job_detail_screen.dart';
import 'screens/candidate/candidate_job_feed_screen.dart';
import 'screens/candidate/candidate_profile_settings_screen.dart';
import 'screens/candidate/candidate_resume_management_screen.dart';
import 'screens/dashboard/command_deck_screen.dart';
import 'screens/hr/analytics_screen.dart';
import 'screens/hr/candidate_report_screen.dart';
import 'screens/hr/create_role_screen.dart';
import 'screens/hr/hr_pipeline_screen.dart';
import 'screens/hr/interview_review_screen.dart';
import 'screens/hr/live_monitor_screen.dart';
import 'screens/hr/org_team_screen.dart';
import 'screens/hr/rankings_screen.dart';
import 'screens/hr/schedule_interview_screen.dart';
import 'screens/hr/settings_screen.dart';
import 'screens/welcome/aperture_splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'widgets/role_guard.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set the status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Initialise the platform-specific auth backend.
  await initializePlatformAuth(EnvConfig.clerkPublishableKey);

  runApp(
    // On native: wraps in ClerkAuth(...) widget
    // On web:    returns child directly (clerk-js manages its own state)
    wrapWithPlatformAuth(
      publishableKey: EnvConfig.clerkPublishableKey,
      child: const SkillSenseApp(),
    ),
  );
}

/// Global navigator key — used for programmatic navigation without BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SkillSenseApp extends StatelessWidget {
  const SkillSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Configure ApiClient token supplier dynamically from the auth service.
    ApiClient.setTokenSupplier(() async {
      try {
        return await AuthService.instance.getSessionToken();
      } catch (_) {
        return null;
      }
    });

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
      // On native: ClerkAuthBuilder (signed-in / signed-out routing)
      // On web:    StreamBuilder listening to clerk-js auth state
      home: buildPlatformHome(
        signedInBuilder: (role) {
          if (role == EnvConfig.roleRecruiter) {
            return const CommandDeckScreen();
          } else {
            return const CandidateHomeScreen();
          }
        },
        signedOutWidget: const ApertureSplashScreen(),
      ),
      onGenerateRoute: (settings) {
        Widget builder;
        switch (settings.name) {
          case '/auth':
          case '/login':
            builder = const LoginScreen();
            break;
          case '/login/role':
            builder = const login_role.RoleSelectionScreen();
            break;
          case '/signup':
          case '/signup/role':
            builder = const SignupRoleSelectionScreen();
            break;
          case '/onboarding/candidate':
          case '/candidate/onboarding':
            builder = const CandidateOnboardingFlow();
            break;
          case '/onboarding/hr':
          case '/hr/onboarding':
            builder = const HrOnboardingFlow();
            break;
          case '/signup/candidate':
            builder = const CandidateRegisterScreen();
            break;
          case '/signup/hr':
            builder = const HrRegisterScreen();
            break;
          case '/welcome':
            builder = const WelcomeScreen();
            break;
          case '/dashboard':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: CommandDeckScreen(),
            );
            break;
          case '/pipeline':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: HrPipelineScreen(),
            );
            break;
          case '/report':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: CandidateReportScreen(),
            );
            break;
          case '/monitor':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: LiveMonitorScreen(),
            );
            break;
          case '/create-role':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: CreateRoleScreen(),
            );
            break;
          case '/schedule':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: ScheduleInterviewScreen(),
            );
            break;
          case '/rankings':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: RankingsScreen(),
            );
            break;
          case '/analytics':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: AnalyticsScreen(),
            );
            break;
          case '/review':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: InterviewReviewScreen(),
            );
            break;
          case '/settings':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: SettingsScreen(),
            );
            break;
          case '/org':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleRecruiter],
              child: OrgTeamScreen(),
            );
            break;
          case '/candidate/home':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateHomeScreen(),
            );
            break;
          case '/candidate/applications':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateApplicationsScreen(),
            );
            break;
          case '/candidate/jobs':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateJobFeedScreen(),
            );
            break;
          case '/candidate/job-detail':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateJobDetailScreen(),
            );
            break;
          case '/candidate/interview-lobby':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateInterviewLobbyScreen(),
            );
            break;
          case '/candidate/interview-session':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateInterviewSessionScreen(),
            );
            break;
          case '/candidate/feedback-report':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateFeedbackReportScreen(),
            );
            break;
          case '/candidate/resumes':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateResumeManagementScreen(),
            );
            break;
          case '/candidate/interviews':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateInterviewHistoryScreen(),
            );
            break;
          case '/candidate/profile':
            builder = const RoleGuard(
              allowedRoles: [EnvConfig.roleCandidate],
              child: CandidateProfileSettingsScreen(),
            );
            break;
          default:
            builder = const WelcomeScreen();
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
