import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/resume_detail.dart';
import 'package:skillsense_ai/screens/hr/hr_pipeline_screen.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/application_service.dart';

Job _job() => Job.fromJson({
  'id': 'job-1',
  'recruiter': 'recruiter-1',
  'title': 'Backend Engineer',
  'description': 'Build the backend',
  'location': 'Remote',
  'status': 'ACTIVE',
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
});

Application _application(
  String status, {
  String id = 'application-1',
  String coverNote = '',
}) => Application.fromJson({
  'id': id,
  'candidate': 'candidate-1',
  'candidate_name': 'Natasha Fatima',
  'candidate_email': 'natasha@example.com',
  'job': 'job-1',
  'job_title': 'Backend Engineer',
  'status': status,
  'resume_id': 'resume-1',
  'cover_note': coverNote,
  'created_at': DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String(),
});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'shortlist POST sends version and reads status and interview eligibility',
    () async {
      final app = _application('APPLIED');
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/applications/application-1/shortlist/');
            expect(options.data, {
              'expected_version': app.version,
              'reason': 'Selected for shortlist from applicant detail.',
            });
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'status': 'SHORTLISTED', 'eligible_for_interview': true},
              ),
            );
          },
        ),
      );

      final updated = await ApplicationService.shortlistApplication(
        app,
        client: dio,
      );
      expect(updated.id, app.id);
      expect(updated.rawStatus, 'SHORTLISTED');
      expect(updated.eligibleForInterview, isTrue);
    },
  );

  testWidgets('UNDER_REVIEW card shortlists and enables interview scheduling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final applied = _application('APPLIED');
    final app = _application('UNDER_REVIEW', id: 'application-2');
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadApplications: (_) async => [applied, app],
          shortlistApplication: (candidate) async {
            calls++;
            expect(candidate.id, app.id);
            return candidate.withShortlistResult({
              'status': 'SHORTLISTED',
              'eligible_for_interview': true,
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Natasha Fatima'), findsNWidgets(2));
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Shortlist'), findsOneWidget);
    expect(find.text('APPLIED · 1'), findsOneWidget);
    expect(find.text('UNDER_REVIEW · 1'), findsOneWidget);
    expect(find.text('SHORTLISTED · 0'), findsOneWidget);
    final schedule = find.byKey(const Key('pipeline-schedule-interview'));
    expect(tester.widget<FilledButton>(schedule).onPressed, isNull);

    await tester.tap(find.text('Shortlist'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('APPLIED · 1'), findsOneWidget);
    expect(find.text('UNDER_REVIEW · 0'), findsOneWidget);
    expect(find.text('SHORTLISTED · 1'), findsOneWidget);
    expect(find.text('Natasha Fatima'), findsNWidgets(2));
    expect(tester.widget<FilledButton>(schedule).onPressed, isNotNull);
    expect(find.text('Candidate shortlisted.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exact API statuses fill five columns without a job dropdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const statuses = [
      'APPLIED',
      'UNDER_REVIEW',
      'SHORTLISTED',
      'INTERVIEWED',
      'DECIDED',
    ];
    var requestedJob = '';
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [
            _job(),
            Job.fromJson({
              'id': 'job-2',
              'recruiter': 'recruiter-1',
              'title': 'Other Job',
              'description': 'Another role',
              'location': 'Remote',
              'status': 'ACTIVE',
              'created_at': '2026-10-01T00:00:00Z',
              'updated_at': '2026-10-01T00:00:00Z',
            }),
          ],
          loadApplications: (id) async {
            requestedJob = id;
            return [
              for (var index = 0; index < statuses.length; index++)
                _application(statuses[index], id: 'application-$index'),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedJob, 'job-1');
    for (final status in statuses) {
      expect(find.text('$status · 1'), findsOneWidget);
    }
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.text('Other Job'), findsNothing);
    expect(find.text('Review screening'), findsNothing);
    expect(find.text('Schedule interview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('View opens applicant preview and Escape restores button focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _application('APPLIED', coverNote: 'I enjoy backend work.');
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadApplications: (_) async => [app],
          loadApplication: (_) async => app,
          loadResume: (_) async => ResumeDetail(
            id: 'resume-1',
            status: ResumeStatus.parsed,
            filename: 'fatima-cv.pdf',
            fileSize: 4096,
            uploadedAt: DateTime.utc(2026, 10, 13),
            skills: const ['Dart'],
            experience: const [
              {'title': 'Engineer', 'company': 'Acme', 'duration': '2 years'},
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Applicant — Natasha Fatima'), findsOneWidget);
    expect(find.text('natasha@example.com'), findsOneWidget);
    expect(find.text('fatima-cv.pdf'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('I enjoy backend work.'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Shortlist'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.textContaining('Screening'), findsNothing);
    expect(find.textContaining('Match score'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Applicant — Natasha Fatima'), findsNothing);
    expect(find.text('APPLIED · 1'), findsOneWidget);
    final view = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'View'),
    );
    expect(view.focusNode?.hasFocus, isTrue);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Applicant — Natasha Fatima'), findsNothing);
    expect(find.text('APPLIED · 1'), findsOneWidget);
  });

  testWidgets('preview Shortlist moves applicant and updates counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _application('APPLIED');
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadApplications: (_) async => [app],
          loadApplication: (_) async => app,
          loadResume: (_) async =>
              const ResumeDetail(id: 'resume-1', status: ResumeStatus.pending),
          shortlistApplication: (candidate) async {
            calls++;
            return candidate.withShortlistResult({
              'status': 'SHORTLISTED',
              'eligible_for_interview': true,
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Parsing…'), findsOneWidget);
    expect(find.text('No cover note provided.'), findsOneWidget);
    await tester.tap(find.text('Shortlist'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Applicant — Natasha Fatima'), findsNothing);
    expect(find.text('APPLIED · 0'), findsOneWidget);
    expect(find.text('SHORTLISTED · 1'), findsOneWidget);
    expect(find.text('Candidate shortlisted.'), findsOneWidget);
  });

  testWidgets('preview Reject moves applicant into DECIDED', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _application('APPLIED');
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadApplications: (_) async => [app],
          loadApplication: (_) async => app,
          loadResume: (_) async =>
              const ResumeDetail(id: 'resume-1', status: ResumeStatus.failed),
          rejectApplication: (_) async {
            calls++;
            return _application('REJECTED');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Applicant — Natasha Fatima'), findsNothing);
    expect(find.text('APPLIED · 0'), findsOneWidget);
    expect(find.text('DECIDED · 1'), findsOneWidget);
    expect(find.text('Candidate rejected.'), findsOneWidget);
  });

  testWidgets('mobile View uses dismissible bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _application('APPLIED');
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadApplications: (_) async => [app],
          loadApplication: (_) async => app,
          loadResume: (_) async =>
              throw const ApiException(statusCode: 404, message: 'Not found'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Resume not available'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('APPLIED · 1'), findsOneWidget);
  });

  testWidgets('a rejected shortlist keeps the card in UNDER_REVIEW', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HrPipelineScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadApplications: (_) async => [_application('UNDER_REVIEW')],
          shortlistApplication: (_) async => throw const ApiException(
            statusCode: 400,
            message: 'Invalid stage',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shortlist'));
    await tester.pumpAndSettle();
    expect(find.text('UNDER_REVIEW · 1'), findsOneWidget);
    expect(find.text('SHORTLISTED · 0'), findsOneWidget);
    expect(find.text('Cannot shortlist from current stage.'), findsOneWidget);
  });
}
