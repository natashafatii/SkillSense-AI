// Recruiter fixture explicitly supplies its verified role to the private service.
import 'package:skillsense_ai/services/recruitment_workflow_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsense_ai/screens/dashboard/command_deck_screen.dart';
import 'package:skillsense_ai/screens/hr/analytics_screen.dart';
import 'package:skillsense_ai/screens/hr/create_role_screen.dart';
import 'package:skillsense_ai/screens/hr/interview_review_screen.dart';
import 'package:skillsense_ai/screens/hr/hr_pipeline_screen.dart';
import 'package:skillsense_ai/screens/hr/job_listings_screen.dart';
import 'package:skillsense_ai/screens/hr/live_monitor_screen.dart';
import 'package:skillsense_ai/screens/hr/settings_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/auth_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    // Verification lives outside test/ because that directory is ignored.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUserNotifier.value = {'email': 'owner@example.com'};
    ApiClient.reset();
    ApiClient.setTokenSupplier(() async => 'test-token');
  });
  tearDown(() {
    ApiClient.reset();
    AuthService.currentUserNotifier.value = null;
  });

  testWidgets('mobile Overview background continues behind the floating dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: const {
                'count': 0,
                'next': null,
                'previous': null,
                'results': <Object>[],
              },
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/command-deck',
          body: CommandDeckScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final bar = tester.getRect(
      find.byKey(const Key('recruiter-mobile-main-nav')),
    );
    expect(bar, const Rect.fromLTRB(14, 716, 376, 776));
    final content = tester.getRect(
      find.byKey(const Key('mobile-content-edge-shadow')),
    );
    expect(content.bottom, 800);
    expect(content.bottom, greaterThan(bar.bottom));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'Create Role does not keep Command Deck polling in the background',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      final client = await ApiClient.getInstance();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request.path);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: const {
                  'count': 0,
                  'next': null,
                  'previous': null,
                  'results': <Object>[],
                },
              ),
            );
          },
        ),
      );

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: RecruiterScaffold(
            currentRoute: '/recruiter/command-deck',
            body: CommandDeckScreen(),
          ),
          routes: {
            '/recruiter/create-role': (_) => RecruiterScaffold(
              currentRoute: '/recruiter/create-role',
              body: CreateRoleScreen(),
            ),
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, contains('/jobs/'));

      navigatorKey.currentState!.pushNamed('/recruiter/create-role');
      await tester.pumpAndSettle();
      requests.clear();
      await tester.pump(const Duration(seconds: 35));
      await tester.pump();

      expect(find.byType(CreateRoleScreen), findsOneWidget);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct Create Role route makes no dashboard API requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: const {
                'count': 0,
                'next': null,
                'previous': null,
                'results': <Object>[],
              },
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/recruiter/create-role',
        home: RecruiterScaffold(
          currentRoute: '/recruiter/command-deck',
          body: CommandDeckScreen(),
        ),
        routes: {
          '/recruiter/create-role': (_) => RecruiterScaffold(
            currentRoute: '/recruiter/create-role',
            body: CreateRoleScreen(),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 35));
    await tester.pump();

    expect(find.byType(CreateRoleScreen), findsOneWidget);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden analytics and interview screens stop polling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.path == '/analytics/overview/'
                  ? <String, dynamic>{}
                  : <Object>[],
            ),
          );
        },
      ),
    );

    for (final screen in <Widget>[
      const LiveMonitorScreen(),
      InterviewReviewScreen(
        service: RecruitmentWorkflowService(role: () => 'RECRUITER'),
      ),
    ]) {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: screen,
          routes: {'/recruiter/create-role': (_) => const CreateRoleScreen()},
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, isNotEmpty);

      navigatorKey.currentState!.pushNamed('/recruiter/create-role');
      await tester.pumpAndSettle();
      requests.clear();
      await tester.pump(const Duration(seconds: 35));
      await tester.pump();
      expect(
        requests,
        isEmpty,
        reason: '${screen.runtimeType} polled while hidden',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing recruiter endpoints are requested only once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          handler.reject(
            DioException(
              requestOptions: request,
              response: Response(requestOptions: request, statusCode: 404),
            ),
          );
        },
      ),
    );

    for (final (screen, endpoint) in <(Widget, String)>[
      (const CommandDeckScreen(), '/jobs/'),
      (const LiveMonitorScreen(), '/interviews/'),
      (
        InterviewReviewScreen(
          service: RecruitmentWorkflowService(role: () => 'RECRUITER'),
        ),
        '/interviews/',
      ),
    ]) {
      requests.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(requests.where((path) => path == endpoint), hasLength(1));
      await tester.pump(const Duration(seconds: 65));
      await tester.pump();
      expect(requests.where((path) => path == endpoint), hasLength(1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable recruiter endpoints never load by default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          handler.resolve(Response(requestOptions: request, statusCode: 200));
        },
      ),
    );

    for (final screen in <Widget>[
      const SettingsScreen(),
      const AnalyticsScreen(),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 35));
      expect(
        requests,
        isEmpty,
        reason: '${screen.runtimeType} made an API request',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('job list screens fetch once and stop on Create Role', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final client = await ApiClient.getInstance();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: const {
                'count': 0,
                'next': null,
                'previous': null,
                'results': <Object>[],
              },
            ),
          );
        },
      ),
    );

    for (final screen in <Widget>[
      const HrPipelineScreen(),
      const JobListingsScreen(),
    ]) {
      requests.clear();
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: screen,
          routes: {'/recruiter/create-role': (_) => const CreateRoleScreen()},
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.where((path) => path == '/jobs/'), hasLength(1));

      navigatorKey.currentState!.pushNamed('/recruiter/create-role');
      await tester.pumpAndSettle();
      requests.clear();
      await tester.pump(const Duration(seconds: 35));
      await tester.pump();
      expect(
        requests,
        isEmpty,
        reason: '${screen.runtimeType} fetched while hidden',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
