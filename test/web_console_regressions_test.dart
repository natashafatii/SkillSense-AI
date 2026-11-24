import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/interview.dart';
import 'package:skillsense_ai/models/interview_analysis_contract.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/paginated_response.dart';
import 'package:skillsense_ai/models/recruitment_evidence.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_feed_screen.dart';
import 'package:skillsense_ai/screens/candidate/widgets/candidate_job_card.dart';
import 'package:skillsense_ai/screens/hr/analytics_screen.dart';
import 'package:skillsense_ai/screens/hr/recruitment_review_screen.dart';
import 'package:skillsense_ai/screens/hr/schedule_interview_screen.dart';
import 'package:skillsense_ai/services/api_client.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/notification_service.dart';
import 'package:skillsense_ai/services/recruitment_workflow_service.dart';
import 'package:skillsense_ai/services/session_scope.dart';
import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/widgets/recruiter_interview_dashboard.dart';
import 'package:skillsense_ai/widgets/recruiter_side_nav.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

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
  testWidgets('recruiter can approve the question draft inline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const timestamp = '2026-01-01T00:00:00Z';
    final job = _job('job', 'Engineer');
    final application = Application.fromJson({
      'id': 'application',
      'job': job.id,
      'status': 'SCREENED',
      'eligible_for_interview': true,
      'created_at': timestamp,
    });
    const draft = {
      'id': 'draft',
      'revision': 2,
      'generation_status': 'READY',
      'questions': [
        {
          'id': 'question',
          'text': 'How do you verify a database migration?',
          'category': 'TECHNICAL',
          'source': 'GENERATED',
          'position': 0,
        },
      ],
    };
    final client = Dio();
    addTearDown(() => client.close(force: true));
    final commands = <Object?>[];
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'PATCH') {
            commands.add(request.data);
          }
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                ...draft,
                if (request.method == 'PATCH') 'approved_at': timestamp,
              },
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          questionClient: client,
          loadJobs: () async => [job],
          loadForJob: (_) async => [application],
          loadBooked: (_) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Interview questions'), findsOneWidget);
    expect(find.text('Interview coverage'), findsOneWidget);
    expect(find.text('Add question'), findsOneWidget);
    expect(
      find.text('How do you verify a database migration?'),
      findsOneWidget,
    );

    final approve = find.text('Approve question set');
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(commands, [
      {'operation': 'approve', 'expected_revision': 2},
    ]);
    expect(find.text('Approved for scheduling'), findsOneWidget);
    expect(find.text('Continue to scheduling'), findsNothing);
    expect(find.text('Interview question editor'), findsNothing);
  });

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
      'interview_session_id': 'session',
    });
    final service = _RecordingMetadataFixture();
    await _show(
      tester,
      1200,
      Scaffold(
        body: SingleChildScrollView(
          child: RecruiterInterviewDashboard(
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
      ),
    );
    expect(find.text('Could not load the recording.'), findsOneWidget);
    expect(find.text('Interim report'), findsOneWidget);
    expect(find.text('Facial expression analysis disabled'), findsOneWidget);
    expect(find.text('Phone visible · Insufficient coverage'), findsOneWidget);
    expect(find.text('Gaze away · Unavailable (uncalibrated)'), findsOneWidget);
    expect(find.text('No face observed · Review disabled'), findsOneWidget);
    expect(
      find.text(
        '3 frame detections · 1 at entry threshold · Below-duration runs 1',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Supported 0.5 s · Unmeasured 7.5 s'),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('Final report'), findsOneWidget);
    expect(find.text('Facial expression analysis disabled'), findsOneWidget);
    expect(
      find.text('Phone visible · Measured, no event observed'),
      findsOneWidget,
    );
    expect(find.text('Gaze away · Unavailable (uncalibrated)'), findsOneWidget);
    await tester.tap(find.text('Retry recording'));
    await tester.pumpAndSettle();

    expect(service.requests, 2);
    expect(find.byTooltip('Load recording'), findsWidgets);
    expect(find.text('Loading recording…'), findsNothing);
    expect(find.text('Camera evidence coverage'), findsOneWidget);
    expect(find.text('1 coverage gap · 4.0 seconds'), findsOneWidget);
    expect(service.reportSessions, ['session', 'session']);
    final diagnostics = find.text('Camera evidence coverage');
    await tester.ensureVisible(diagnostics);
    await tester.tap(diagnostics);
    await tester.pumpAndSettle();
    expect(find.textContaining('worker unready (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final original = VideoPlayerPlatform.instance;
    final player = _ReplayVideoFixture();
    VideoPlayerPlatform.instance = player;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await tester.ensureVisible(find.byTooltip('Load recording').first);
    await tester.tap(find.byTooltip('Load recording').first);
    await tester.pumpAndSettle();
    expect(player.source?.uri, 'https://recording.example.test/replay.mp4');
    expect(find.byKey(const ValueKey('replay-video-frame')), findsOneWidget);
    expect(service.audioAccesses, 0);
    expect(tester.takeException(), isNull);
  });

  test('video replay access accepts a signed ready or partial replay only', () async {
    final client = Dio();
    addTearDown(() => client.close(force: true));
    var state = 'ready';
    var ttl = 180;
    const url = 'https://recording.example.test/replay.mp4?signature=fixture';
    client.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/interviews/interview/replay/');
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'state': state, 'expires_in': ttl, 'url': url},
      ));
    }));
    final service = RecruitmentWorkflowService(
      client: () async => client,
      role: () => 'RECRUITER',
    );
    expect((await service.replayAccess('interview')).uri.toString(), url);
    state = 'partial';
    expect((await service.replayAccess('interview')).uri.toString(), url);
    ttl = 0;
    expect((await service.replayAccess('interview')).uri, isNull);
    ttl = 180;
    state = 'processing';
    expect(await service.replayAccess('interview'), (uri: null, state: state));
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
  int audioAccesses = 0;
  final reportSessions = <String>[];

  @override
  Future<({Uri? uri, String state})> replayAccess(
    String interviewId, {
    CancelToken? cancelToken,
  }) async => (
    uri: Uri.parse('https://recording.example.test/replay.mp4'),
    state: 'ready',
  );

  @override
  Future<({Uri? uri, String? reason})> recordingAccess(
    String interviewId, {
    CancelToken? cancelToken,
  }) async {
    audioAccesses++;
    return (uri: null, reason: null);
  }

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

  @override
  Future<RecruiterReportResult> interviewBehavior(
    InterviewSessionIdentity identity, {
    CancelToken? cancelToken,
  }) async {
    reportSessions.add(identity.sessionId);
    final revision = reportSessions.length;
    final finalReport = revision > 1;
    final duration = finalReport ? 2.0 : 0.5;
    return RecruiterReportResult.fromJson({
      'session_id': identity.sessionId,
      'availability': 'ready',
      'revision': revision,
      'report': {
        'schema_version': 1,
        'revision': revision,
        'status': finalReport ? 'complete' : 'processing',
        'final': finalReport,
        'signal_review': {
          'phone_visible': true,
          'no_face_observed': false,
          'multiple_people_observed': false,
        },
        'limitations': ['gaze_not_calibrated'],
        'generated_at': '2026-10-18T00:00:10Z',
        'coverage': {
          'received': 6,
          'admitted': 5,
          'processed': 5,
          'usable_frames': 5,
          'dropped': 1,
          'superseded': 0,
          'failed': 0,
          'expired': 0,
          'valid_gaze': 0,
          'unknown_gaze': 5,
          'known_seconds': {'face': duration, 'objects': duration, 'gaze': 0},
          'longest_supported_seconds': {
            'face': duration,
            'objects': duration,
            'gaze': 0,
          },
          'minimum_episode_seconds': 2,
          'evidence_window_seconds': 8,
          'camera_diagnostics': {
            'latest_processed_at': '2026-10-18T00:00:09Z',
            'latest_usable_sample_at': '2026-10-18T00:00:08Z',
            'gap_count': 1,
            'gap_seconds': 4,
            'latest_gap': {
              'start': '2026-10-18T00:00:03Z',
              'end': '2026-10-18T00:00:07Z',
            },
            'drop_reasons': {'worker_unready': 1},
            'terminal_reasons': <String, int>{},
            'signal_samples': null,
          },
        },
        'observations': [],
        'episodes': {
          'events': [],
          'episode_counts': {'phone_visible': 0, 'no_face_observed': 0},
          'observed_seconds': {'phone_visible': 0, 'no_face_observed': 0},
          'signal_diagnostics': {
            'phone_visible': {
              'frame_detections': 3,
              'entry_qualified_frames': 1,
              'below_onset_runs': 1,
            },
          },
        },
        'versions': <String, List<String>>{},
        'expression': {'status': finalReport ? 'complete' : 'disabled'},
      },
    }, sessionId: identity.sessionId);
  }
}

class _ReplayVideoFixture extends VideoPlayerPlatform {
  DataSource? source;

  @override
  Future<void> init() async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 5),
      size: const Size(640, 360),
    ),
  );

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox(key: ValueKey('replay-video-frame'));

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> dispose(int playerId) async {}
}
