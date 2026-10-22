import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skillsense_ai/constants/app_colors.dart';
import 'package:skillsense_ai/constants/env_config.dart';
import 'models/job.dart';
import 'models/interview_analysis_contract.dart';
import 'services/media/interview_media_route_observer.dart';

// Conditional import: picks the web or native platform integration.
import 'services/platform_app_stub.dart'
    if (dart.library.js_interop) 'services/platform_app_web.dart'
    if (dart.library.io) 'services/platform_app_native.dart';

import 'screens/login/login_screen.dart';
import 'screens/login/role_selection_screen.dart' as login_role;
import 'screens/signup/signup_role_selection_screen.dart';
import 'screens/signup/candidate_register_screen.dart';
import 'screens/signup/hr_register_screen.dart';
import 'screens/signup/google_callback_screen.dart';
import 'screens/candidate/candidate_onboarding_flow.dart';
import 'screens/hr/hr_onboarding_flow.dart';
import 'screens/candidate/candidate_applications_screen.dart';
import 'screens/candidate/candidate_feedback_report_screen.dart';
import 'screens/candidate/candidate_home_screen.dart';
import 'screens/candidate/candidate_interview_history_screen.dart';
import 'screens/candidate/candidate_interview_lobby_screen.dart';
import 'screens/candidate/candidate_interview_session_screen.dart';
import 'screens/candidate/candidate_job_detail_route.dart';
import 'screens/candidate/candidate_job_feed_screen.dart';
import 'screens/candidate/candidate_profile_settings_screen.dart';
import 'screens/candidate/candidate_notifications_screen.dart';
import 'screens/candidate/candidate_resume_management_screen.dart';
import 'screens/dashboard/command_deck_screen.dart';
import 'screens/hr/analytics_screen.dart';
import 'screens/admin/admin_portal.dart';
import 'screens/admin/aurora_tokens.dart';
import 'screens/hr/candidate_report_screen.dart';
import 'screens/hr/create_role_screen.dart';
import 'screens/hr/hr_pipeline_screen.dart';
import 'screens/hr/interview_review_screen.dart';
import 'screens/hr/live_monitor_screen.dart';
import 'screens/hr/recruiter_observation_screen.dart';
import 'screens/hr/rankings_screen.dart';
import 'screens/hr/schedule_interview_screen.dart';

import 'screens/hr/job_listings_screen.dart';
import 'screens/hr/recruiter_job_detail_screen.dart';
import 'screens/hr/recruiter_profile_screen.dart';
import 'screens/signup/terms_privacy_screen.dart';
import 'screens/welcome/aperture_splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'widgets/role_guard.dart';
import 'widgets/recruiter_scaffold.dart';
import 'widgets/mobile_home_indicator.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/route_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final adminLaunchRoute = adminRoutes.values.cast<String?>().firstWhere(
    (route) =>
        route == Uri.base.fragment.split('?').first || route == Uri.base.path,
    orElse: () => null,
  );
  if (adminLaunchRoute != null) {
    runApp(SkillSenseApp(initialAdminRoute: adminLaunchRoute));
    return;
  }

  // Set the status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  Object? authInitializationError;
  try {
    // Initialise the platform-specific auth backend before rendering routes
    // that depend on the current session.
    await initializePlatformAuth(EnvConfig.clerkPublishableKey);
  } catch (error) {
    authInitializationError = error;
  }

  if (authInitializationError != null) {
    runApp(AuthInitializationFailure(error: authInitializationError));
    return;
  }

  runApp(
    // Both platforms use the verified session owned by AuthService.
    wrapWithPlatformAuth(
      publishableKey: EnvConfig.clerkPublishableKey,
      child: const SkillSenseApp(),
    ),
  );
}

class AuthInitializationFailure extends StatelessWidget {
  final Object error;

  const AuthInitializationFailure({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('TimeoutException: ', '');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      builder: mobileHomeIndicatorBuilder,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Unable to start authentication',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Check the network connection, then reload this page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Global navigator key — used for programmatic navigation without BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = previousRoute?.settings.name;
    if (name != null && name != '/' && !adminRoutes.containsValue(name)) {
      RouteStorage.saveLastRoute(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null &&
        route.settings.name != '/' &&
        !adminRoutes.containsValue(route.settings.name)) {
      RouteStorage.saveLastRoute(route.settings.name!);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute?.settings.name != null &&
        newRoute!.settings.name != '/' &&
        !adminRoutes.containsValue(newRoute.settings.name)) {
      RouteStorage.saveLastRoute(newRoute.settings.name!);
    }
  }
}

class SkillSenseApp extends StatelessWidget {
  const SkillSenseApp({super.key, this.initialAdminRoute});
  final String? initialAdminRoute;

  @override
  Widget build(BuildContext context) {
    // Configure ApiClient token supplier dynamically from the auth service.
    if (initialAdminRoute == null) {
      ApiClient.setTokenSupplier(() async {
        try {
          return await AuthService.getSessionToken();
        } catch (_) {
          return null;
        }
      });
    }

    final googleCallback =
        initialAdminRoute == null && AuthService.isGoogleCallback;
    return MaterialApp(
      title: 'SkillSense AI',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      builder: mobileHomeIndicatorBuilder,
      navigatorKey: navigatorKey,
      navigatorObservers: [AppRouteObserver(), interviewMediaRouteObserver],
      initialRoute:
          initialAdminRoute ?? (googleCallback ? '/oauth/callback' : null),
      onGenerateInitialRoutes: initialAdminRoute != null
          ? (_) => [
              MaterialPageRoute<void>(
                settings: RouteSettings(name: initialAdminRoute),
                builder: (adminContext) {
                  final brightness = MediaQuery.platformBrightnessOf(
                    adminContext,
                  );
                  return Theme(
                    data: auroraTheme(
                      brightness == Brightness.dark
                          ? AuroraTokens.auroraNight
                          : AuroraTokens.auroraDay,
                      brightness,
                    ),
                    child: AdminPortal(
                      module: adminRoutes.entries
                          .firstWhere((e) => e.value == initialAdminRoute)
                          .key,
                    ),
                  );
                },
              ),
            ]
          : googleCallback
          ? (_) => [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/oauth/callback'),
                builder: (_) => const GoogleCallbackScreen(),
              ),
            ]
          : null,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        extensions: const [AuroraTokens.auroraDay],
      ),
      darkTheme: auroraTheme(AuroraTokens.auroraNight, Brightness.dark),
      themeMode: ThemeMode.system,
      // Routing observes only backend-verified application sessions.
      home: initialAdminRoute == null && !googleCallback
          ? buildPlatformHome(
              signedInBuilder: (role) {
                return const RoleGuard(
                  allowedRoles: [
                    EnvConfig.roleRecruiter,
                    EnvConfig.roleCandidate,
                  ],
                  child: _VerifiedHome(),
                );
              },
              signedOutWidget: const ApertureSplashScreen(),
            )
          : null,
      onGenerateRoute: (settings) {
        // Old detail links carry their ID only in memory. Keep the ID in the
        // URL so refresh restores it; an unselected detail link opens the feed.
        if (settings.name == '/candidate/job-detail') {
          final id = CandidateJobDetailRoute.jobIdFrom(settings.arguments);
          settings = RouteSettings(
            name: id == null
                ? '/candidate/jobs'
                : '/candidate/jobs/${Uri.encodeComponent(id)}',
          );
        }
        if (settings.name != null &&
            settings.name != '/' &&
            !adminRoutes.containsValue(settings.name)) {
          RouteStorage.saveLastRoute(settings.name!);
        }

        final name = settings.name ?? '';
        Widget builder;

        if (adminRoutes.containsValue(name)) {
          final module = adminRoutes.entries
              .firstWhere((e) => e.value == name)
              .key;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (adminContext) => Theme(
              data: auroraTheme(
                MediaQuery.platformBrightnessOf(adminContext) == Brightness.dark
                    ? AuroraTokens.auroraNight
                    : AuroraTokens.auroraDay,
                MediaQuery.platformBrightnessOf(adminContext),
              ),
              child: AdminPortal(
                module: module,
                initialAnalyticsTab: settings.arguments as String?,
              ),
            ),
          );
        }

        // Deep link handling for job detail route: /candidate/jobs/:id
        if (name.startsWith('/candidate/jobs/') &&
            name.length > '/candidate/jobs/'.length) {
          final id = Uri.decodeComponent(
            name.substring('/candidate/jobs/'.length),
          );
          builder = RoleGuard(
            allowedRoles: const [EnvConfig.roleCandidate],
            child: CandidateJobDetailRoute(arguments: id),
          );
        } else if (name.startsWith('/recruiter/jobs/') &&
            name.endsWith('/pipeline') &&
            name.length > '/recruiter/jobs//pipeline'.length) {
          final id = Uri.decodeComponent(
            name.substring(
              '/recruiter/jobs/'.length,
              name.length - '/pipeline'.length,
            ),
          );
          builder = RoleGuard(
            allowedRoles: const [EnvConfig.roleRecruiter],
            child: HrPipelineScreen(jobId: id),
          );
        } else if (name.startsWith('/recruiter/jobs/') &&
            name.length > '/recruiter/jobs/'.length) {
          final id = Uri.decodeComponent(
            name.substring('/recruiter/jobs/'.length),
          );
          builder = RoleGuard(
            allowedRoles: const [EnvConfig.roleRecruiter],
            child: RecruiterJobDetailScreen(jobId: id),
          );
        } else {
          switch (settings.name) {
            case '/login/candidate':
              builder = const LoginScreen(selectedRole: 'CANDIDATE');
              break;
            case '/login/recruiter':
              builder = const LoginScreen(selectedRole: 'RECRUITER');
              break;
            case '/auth':
            case '/login':
              builder = LoginScreen(
                selectedRole: settings.arguments as String?,
              );
              break;
            case '/login/role':
              builder = const login_role.RoleSelectionScreen();
              break;
            case '/oauth/callback':
              builder = const GoogleCallbackScreen();
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
            case '/terms':
            case '/terms-privacy':
              builder = const TermsPrivacyScreen();
              break;
            case '/welcome':
              builder = const WelcomeScreen();
              break;
            case '/dashboard':
            case '/recruiter/command-deck':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: CommandDeckScreen(),
              );
              break;
            case '/pipeline':
            case '/recruiter/pipeline':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: HrPipelineScreen(
                  jobId: settings.arguments is String
                      ? settings.arguments as String
                      : settings.arguments is Map
                      ? (settings.arguments as Map)['jobId']?.toString()
                      : null,
                ),
              );
              break;
            case '/report':
            case '/recruiter/candidate-report':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: settings.arguments is RecruiterObservationTarget
                    ? RecruiterObservationScreen(
                        target:
                            settings.arguments! as RecruiterObservationTarget,
                      )
                    : const CandidateReportScreen(),
              );
              break;
            case '/monitor':
            case '/recruiter/live-monitor':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: LiveMonitorScreen(
                  observationTarget:
                      settings.arguments is RecruiterObservationTarget
                      ? settings.arguments! as RecruiterObservationTarget
                      : null,
                ),
              );
              break;
            case '/create-role':
            case '/recruiter/create-role':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: CreateRoleScreen(
                  key: const ValueKey('create-role-form-v2'),
                  initialJob: settings.arguments is Job
                      ? settings.arguments as Job
                      : null,
                ),
              );
              break;
            case '/schedule':
            case '/recruiter/schedule-interview':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: ScheduleInterviewScreen(
                  jobId: settings.arguments is String
                      ? settings.arguments as String
                      : settings.arguments is Map
                      ? (settings.arguments as Map)['jobId']?.toString()
                      : null,
                  applicationId: settings.arguments is Map
                      ? (settings.arguments as Map)['applicationId']?.toString()
                      : null,
                ),
              );
              break;
            case '/rankings':
            case '/recruiter/rankings':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: RankingsScreen(
                  jobId: settings.arguments is String
                      ? settings.arguments as String
                      : null,
                ),
              );
              break;
            case '/analytics':
            case '/recruiter/analytics':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: AnalyticsScreen(),
              );
              break;
            case '/review':
            case '/recruiter/interview-review':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: InterviewReviewScreen(),
              );
              break;
            case '/settings':
            case '/recruiter/scoring-model':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: RankingsScreen(),
              );
              break;
            case '/recruiter/profile':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: RecruiterProfileScreen(),
              );
              break;
            case '/recruiter/job-listings':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: JobListingsScreen(),
              );
              break;
            case '/recruiter/notifications':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleRecruiter],
                child: RecruiterNotificationsScreen(),
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
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleCandidate],
                child: CandidateJobDetailRoute(arguments: settings.arguments),
              );
              break;
            case '/candidate/interview-lobby':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleCandidate],
                child: CandidateInterviewLobbyScreen(
                  interviewId: settings.arguments is String
                      ? settings.arguments as String
                      : null,
                  identity: settings.arguments is InterviewSessionIdentity
                      ? settings.arguments as InterviewSessionIdentity
                      : null,
                ),
              );
              break;
            case '/candidate/interview-session':
              builder = RoleGuard(
                allowedRoles: [EnvConfig.roleCandidate],
                child: settings.arguments is InterviewSessionIdentity
                    ? CandidateInterviewSessionScreen(
                        identity:
                            settings.arguments as InterviewSessionIdentity,
                      )
                    : const Scaffold(
                        body: Center(
                          child: Text('A valid interview session is required.'),
                        ),
                      ),
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
            case '/candidate/notifications':
              builder = const RoleGuard(
                allowedRoles: [EnvConfig.roleCandidate],
                child: CandidateNotificationsScreen(),
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
        }
        const recruiterAliases = <String, String>{
          '/dashboard': '/recruiter/command-deck',
          '/pipeline': '/recruiter/pipeline',
          '/report': '/recruiter/candidate-report',
          '/monitor': '/recruiter/live-monitor',
          '/create-role': '/recruiter/create-role',
          '/schedule': '/recruiter/schedule-interview',
          '/rankings': '/recruiter/rankings',
          '/analytics': '/recruiter/analytics',
          '/review': '/recruiter/interview-review',
          '/settings': '/recruiter/scoring-model',
        };
        final canonicalRecruiterRoute =
            recruiterAliases[settings.name] ?? settings.name;
        final isRecruiterRoute =
            canonicalRecruiterRoute?.startsWith('/recruiter/') ?? false;
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              isRecruiterRoute
              ? RecruiterScaffold(
                  currentRoute: canonicalRecruiterRoute!,
                  selectedRoute:
                      canonicalRecruiterRoute.startsWith('/recruiter/jobs/') &&
                          canonicalRecruiterRoute.endsWith('/pipeline')
                      ? '/recruiter/pipeline'
                      : canonicalRecruiterRoute.startsWith('/recruiter/jobs/')
                      ? '/recruiter/job-listings'
                      : null,
                  body: builder,
                )
              : builder,
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
    );
  }
}

class _VerifiedHome extends StatelessWidget {
  const _VerifiedHome();

  @override
  Widget build(BuildContext context) =>
      AuthService.getUserRole() == EnvConfig.roleRecruiter
      ? const RecruiterScaffold(
          currentRoute: '/recruiter/command-deck',
          body: CommandDeckScreen(),
        )
      : const CandidateHomeScreen();
}
