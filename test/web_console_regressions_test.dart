import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/interview.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/models/recruitment_evidence.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_feed_screen.dart';
import 'package:skillsense_ai/screens/candidate/widgets/candidate_job_card.dart';
import 'package:skillsense_ai/screens/hr/analytics_screen.dart';
import 'package:skillsense_ai/screens/hr/recruitment_review_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/notification_service.dart';
import 'package:skillsense_ai/services/recruitment_workflow_service.dart';
import 'package:skillsense_ai/services/session_scope.dart';
import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/widgets/recruiter_interview_dashboard.dart';
import 'package:skillsense_ai/widgets/recruiter_side_nav.dart';

Job _job(String id, String title) => Job.fromJson({
  'id': id,
  'recruiter': 'recruiter',
  'title': title,
  'description': 'Engineering role',
  'location': 'Lahore',
  'status': 'ACTIVE',
  'skills_required': ['Distributed systems', 'Database design', 'Flutter'],
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
});

Future<void> _show(WidgetTester tester, double width, Widget screen) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: AppTypographyTheme(child: child!),
      ),
      home: screen,
    ),
  );
  // The first card pulses while it is visible.
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('interview detail keeps desktop workspace navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Interview list')),
        routes: {
          '/recruiter/interview-review': (_) =>
              const Scaffold(body: Text('Interview list')),
        },
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => RecruitmentReviewScreen(
          applicationId: 'application',
          showInterviewDashboard: true,
          service: _ReviewNavigationFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rail = find.byType(RecruiterSideNav);
    expect(rail, findsOneWidget);
    expect(
      tester.widget<RecruiterSideNav>(rail).selectedRoute,
      '/recruiter/interview-review',
    );
    expect(find.widgetWithText(Tab, 'Overview'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recruiter-collapse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recruiter-interview-review')));
    await tester.pumpAndSettle();
    expect(find.text('Interview list'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(rail, findsNothing);
    expect(find.widgetWithText(Tab, 'Overview'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to interviews'));
    await tester.pumpAndSettle();
    expect(find.text('Interview list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1440.0, 2200.0]) {
    testWidgets('job feed cards fit at width $width with scaled text', (
      tester,
    ) async {
      final jobs = [
        _job('one', 'Senior Software Engineer for Distributed Systems'),
        _job('two', 'Frontend Engineer'),
        _job('three', 'Site Reliability Engineer'),
      ];
      expect(jobs.first.skillsRequired, isNotEmpty);
      await _show(
        tester,
        width,
        CandidateJobFeedScreen(
          loadJobs: (_) async => PaginatedResponse(count: 3, results: jobs),
          loadResumes: () async => [],
        ),
      );
      final cards = find.byType(CandidateJobCard);
      expect(cards, findsNWidgets(3));
      final first = tester.getTopLeft(cards.at(0));
      final second = tester.getTopLeft(cards.at(1));
      if (width == 390) {
        expect(first.dy, lessThan(second.dy));
      } else {
        expect(first.dy, second.dy);
        expect(first.dx, lessThan(second.dx));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('analytics role row fits a two-line title and its age', (
    tester,
  ) async {
    final job = _job('one', 'Senior Software Engineer for Distributed Systems');
    await _show(
      tester,
      1440,
      AnalyticsScreen(
        loadOverview: () async => RecruiterAnalyticsRecords(
          jobs: [job],
          applications: [],
          interviews: [],
        ),
      ),
    );
    final table = find.byType(DataTable);
    final title = find.descendant(of: table, matching: find.text(job.title));
    final age = find.descendant(of: table, matching: find.text('0d open'));
    expect(
      tester.getSize(title).height + tester.getSize(age).height,
      greaterThan(55),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recording metadata can be retried without preloading playback', (
    tester,
  ) async {
    final interview = RecruiterInterview.fromJson({
      'id': 'interview',
      'application': 'application',
      'status': 'DONE',
    });
    final service = _RecordingMetadataFixture();
    await _show(
      tester,
      1200,
      Scaffold(
        body: RecruiterInterviewDashboard(
          service: service,
          refreshVersion: 0,
          review: RecruitmentReview(
            application: Application(
              id: 'application',
              candidate: 'candidate',
              candidateEmail: 'candidate@example.test',
              job: 'job',
              jobTitle: 'Engineer',
              status: ApplicationStatus.interviewed,
              createdAt: DateTime(2026),
            ),
            decision: null,
            attempts: [interview],
            interview: interview,
            transcripts: null,
            evaluations: null,
            scores: ScoreHistory.fromJson({'history': []}),
            actions: [],
            feedback: [],
          ),
        ),
      ),
    );
    expect(find.text('Could not load the recording.'), findsOneWidget);
    await tester.tap(find.text('Retry recording'));
    await tester.pumpAndSettle();

    expect(service.requests, 2);
    expect(find.byTooltip('Load recording'), findsWidgets);
    expect(find.text('Loading recording…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final outcome in ['recovered', 'rejected', 'session changed']) {
    test('unread count retry when auth is $outcome', () async {
      final client = Dio();
      addTearDown(() => client.close(force: true));
      client.interceptors.add(
        ClerkTokenInterceptor(
          tokenSupplier: () async => 'cached',
          refreshTokenSupplier: () async => 'fresh',
        ),
      );
      final authorization = <Object?>[];
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            authorization.add(request.headers['Authorization']);
            if (authorization.length == 1 && outcome == 'session changed') {
              SessionScope.invalidate();
            }
            if (authorization.length == 1 || outcome == 'rejected') {
              handler.reject(
                DioException.badResponse(
                  statusCode: 401,
                  requestOptions: request,
                  response: Response(requestOptions: request, statusCode: 401),
                ),
              );
              return;
            }
            handler.resolve(
              Response(requestOptions: request, data: {'unread_count': 4}),
            );
          },
        ),
      );

      final unread = NotificationService.unreadCount(client: client);
      if (outcome == 'recovered') {
        expect(await unread, 4);
      } else {
        await expectLater(unread, throwsA(isA<ApiException>()));
      }
      expect(authorization, [
        'Bearer cached',
        if (outcome != 'session changed') 'Bearer fresh',
      ]);
    });
  }
}

class _ReviewNavigationFixture extends RecruitmentWorkflowService {
  @override
  Future<RecruitmentReview> review(
    String applicationId, {
    String? interviewId,
    CancelToken? cancelToken,
  }) async => RecruitmentReview(
    application: Application(
      id: applicationId,
      candidate: 'candidate',
      candidateEmail: 'candidate@example.test',
      job: 'job',
      jobTitle: 'Engineer',
      status: ApplicationStatus.interviewed,
      createdAt: DateTime(2026),
    ),
    decision: null,
    attempts: [],
    interview: null,
    transcripts: null,
    evaluations: null,
    scores: ScoreHistory.fromJson({'history': []}),
    actions: [],
    feedback: [],
  );
}

class _RecordingMetadataFixture extends RecruitmentWorkflowService {
  int requests = 0;

  @override
  Future<InterviewRecording> interviewRecording(
    String interviewId, {
    CancelToken? cancelToken,
  }) async {
    if (++requests == 1) throw StateError('Recording metadata unavailable.');
    return InterviewRecording.fromJson({
      'recording_url': 'https://recording.example.test/recording.wav',
    });
  }
}
