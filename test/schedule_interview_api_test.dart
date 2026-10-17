import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/interview.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/schedule_interview_screen.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/application_service.dart';
import 'package:skillsense_ai/services/interview_service.dart';
import 'package:skillsense_ai/widgets/recruiter_scaffold.dart';
import 'package:skillsense_ai/widgets/recruiter_side_nav.dart';

Map<String, dynamic> _appJson(
  String id,
  String status, {
  String job = 'job-1',
}) => {
  'id': id,
  'candidate': 'candidate-$id',
  'candidate_email': '$id@example.com',
  'job': job,
  'job_title': 'Backend Engineer',
  'status': status,
  'created_at': '2026-10-01T00:00:00Z',
};

Job _job() => Job.fromJson({
  'id': 'job-1',
  'recruiter': 'recruiter',
  'title': 'Backend Engineer',
  'description': 'Role',
  'location': 'Remote',
  'status': 'ACTIVE',
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
});

Interview _interview(String id, DateTime slot) =>
    Interview(id: 'interview-1', applicationId: id, scheduledAt: slot);

Future<void> _pickAvailableSlot(WidgetTester tester) async {
  final chips = find.byType(ChoiceChip);
  final index = chips.evaluate().toList().indexWhere(
    (element) => (element.widget as ChoiceChip).onSelected != null,
  );
  expect(index, isNonNegative);
  await tester.tap(chips.at(index));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final hasShortlisted in [false, true]) {
    testWidgets(
      'waits for applications and interviews before showing ${hasShortlisted ? 'live' : 'empty'} layout',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final applications = Completer<List<Application>>();
        final interviews = Completer<List<Interview>>();
        await tester.pumpWidget(
          MaterialApp(
            home: ScheduleInterviewScreen(
              jobId: 'job-1',
              loadJobs: () async => [_job()],
              loadForJob: (_) => applications.future,
              loadBooked: (_) => interviews.future,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('This week'), findsNothing);
        expect(find.text('No interviews scheduled'), findsNothing);

        applications.complete(
          hasShortlisted
              ? [Application.fromJson(_appJson('alice', 'SHORTLISTED'))]
              : <Application>[],
        );
        await tester.pump();
        expect(find.text('This week'), findsNothing);
        expect(find.text('No interviews scheduled'), findsNothing);

        interviews.complete(<Interview>[]);
        await tester.pumpAndSettle();
        expect(
          find.text('This week'),
          hasShortlisted ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('No interviews scheduled'),
          hasShortlisted ? findsNothing : findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.text('This week'),
          hasShortlisted ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('No interviews scheduled'),
          hasShortlisted ? findsNothing : findsOneWidget,
        );
      },
    );
  }

  testWidgets('scheduled interviews keep the live layout with no shortlist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadForJob: (_) async => [],
          loadBooked: (_) async => [
            _interview('alice', DateTime.now().add(const Duration(days: 1))),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('No interviews scheduled'), findsNothing);
  });

  testWidgets('multiple active jobs wait for a selection before loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secondJob = Job.fromJson({
      'id': 'job-2',
      'recruiter': 'recruiter',
      'title': 'Data Engineer',
      'description': 'Role',
      'location': 'Remote',
      'status': 'ACTIVE',
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    });
    final requestedJobs = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          loadJobs: () async => [_job(), secondJob],
          loadForJob: (jobId) async {
            requestedJobs.add(jobId);
            return [
              Application.fromJson(
                _appJson('alice', 'SHORTLISTED', job: 'job-2'),
              ),
            ];
          },
          loadBooked: (_) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select a job to schedule interviews.'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
    expect(requestedJobs, isEmpty);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Engineer').last);
    await tester.pumpAndSettle();
    expect(requestedJobs, ['job-2']);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'job-2',
    );
  });

  testWidgets('no active jobs shows empty state without scheduling calls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var applicationCalls = 0;
    var interviewCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          loadJobs: () async => [],
          loadForJob: (_) {
            applicationCalls++;
            return Future.value([]);
          },
          loadBooked: (_) {
            interviewCalls++;
            return Future.value([]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(applicationCalls, 0);
    expect(interviewCalls, 0);
    expect(find.text('No interviews scheduled'), findsOneWidget);
  });

  testWidgets('scheduling errors show a friendly message and Retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadForJob: (_) async => throw const ApiException(
            statusCode: 400,
            message:
                'job: Recruiters must provide a ?job={id} query parameter.',
          ),
          loadBooked: (_) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select a job to schedule interviews.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('shared shell renders one recruiter nav beside schedule canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/schedule-interview',
          body: ScheduleInterviewScreen(
            jobId: 'job-1',
            loadJobs: () async => [_job()],
            loadForJob: (_) async => [],
            loadBooked: (_) async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecruiterSideNav), findsOneWidget);
    expect(tester.getSize(find.byType(RecruiterSideNav)).width, 60);
    expect(tester.getRect(find.byType(ScheduleInterviewScreen)).left, 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile shell has no side nav and keeps the schedule dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/schedule-interview',
          body: ScheduleInterviewScreen(
            jobId: 'job-1',
            loadJobs: () async => [_job()],
            loadForJob: (_) async => [],
            loadBooked: (_) async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-mobile-dock')), findsOneWidget);
    expect(find.byKey(const Key('recruiter-menu')), findsNothing);
    expect(find.byType(RecruiterSideNav), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).drawer, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: RecruiterScaffold(
          currentRoute: '/recruiter/job-listings',
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recruiter-menu')), findsNothing);
    expect(find.byType(RecruiterSideNav), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).drawer, isNull);
    expect(tester.takeException(), isNull);
  });

  test('shortlisted request includes job and status on every page', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    final requests = <Map<String, dynamic>>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(Map<String, dynamic>.from(options.queryParameters));
          final page = options.queryParameters['page'] as int;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'count': 2,
                'next': page == 1
                    ? 'https://test.invalid/applications/?page=2'
                    : null,
                'previous': null,
                'results': [_appJson('a$page', 'SHORTLISTED')],
              },
            ),
          );
        },
      ),
    );
    final applications = await ApplicationService.listAllForJob(
      'job-1',
      status: 'SHORTLISTED',
      client: dio,
    );
    expect(applications.map((app) => app.id), ['a1', 'a2']);
    expect(requests, [
      {'page': 1, 'job': 'job-1', 'status': 'SHORTLISTED'},
      {'page': 2, 'job': 'job-1', 'status': 'SHORTLISTED'},
    ]);
  });

  test(
    'schedule data requests shortlisted applications and scheduled interviews',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
      final requests = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add('${options.path}?${options.queryParameters}');
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'results': <dynamic>[], 'next': null},
              ),
            );
          },
        ),
      );
      await Future.wait([
        ApplicationService.listAllForJob(
          'job-1',
          status: 'SHORTLISTED',
          client: dio,
        ),
        InterviewService.listForJob('job-1', status: 'SCHEDULED', client: dio),
      ]);
      expect(
        requests,
        contains('/applications/?{page: 1, job: job-1, status: SHORTLISTED}'),
      );
      expect(
        requests,
        contains('/interviews/?{job: job-1, status: SCHEDULED, page: 1}'),
      );
    },
  );

  test('schedule POST sends application and UTC ISO slot', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    Map<String, dynamic>? body;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/interviews/');
          body = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'id': 'interview-1',
                'application': 'application-1',
                'scheduled_at': body!['scheduled_at'],
              },
            ),
          );
        },
      ),
    );
    final slot = DateTime.now().add(const Duration(days: 2));
    final interview = await InterviewService.schedule(
      applicationId: 'application-1',
      scheduledAt: slot,
      client: dio,
    );
    expect(body!['application'], 'application-1');
    expect(body!['scheduled_at'], slot.toUtc().toIso8601String());
    expect(interview.id, 'interview-1');
  });

  testWidgets('only shortlisted rows appear and invite removes scheduled row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var loads = 0;
    String? sentId;
    DateTime? sentSlot;
    final applications = [
      Application.fromJson(_appJson('alice', 'SHORTLISTED')),
      Application.fromJson(_appJson('bob', 'SCREENING')),
      Application.fromJson(_appJson('other', 'SHORTLISTED', job: 'job-2')),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadForJob: (_) async {
            loads++;
            return applications;
          },
          loadBooked: (_) async =>
              sentSlot == null ? [] : [_interview(sentId!, sentSlot!)],
          sendInvite: (id, slot) async {
            sentId = id;
            sentSlot = slot;
            return _interview(id, slot);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Other'), findsNothing);
    expect(find.text('SHORTLIST · 1'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Send invite'),
          )
          .onPressed,
      isNull,
    );
    await _pickAvailableSlot(tester);
    await tester.tap(find.text('Alice'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Send invite'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(sentId, 'alice');
    expect(sentSlot, isNotNull);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('No shortlisted candidates yet'), findsOneWidget);
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('403 scheduling error is shown under the candidate row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadForJob: (_) async => [
            Application.fromJson(_appJson('alice', 'SHORTLISTED')),
          ],
          loadBooked: (_) async => [],
          sendInvite: (_, __) async =>
              throw const ApiException(statusCode: 403, message: 'Forbidden'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pickAvailableSlot(tester);
    await tester.tap(find.text('Alice'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send invite'));
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(
      find.text("You're not authorized to schedule this interview."),
      findsOneWidget,
    );
  });

  testWidgets('400 scheduling validation stays inline with the row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduleInterviewScreen(
          jobId: 'job-1',
          loadJobs: () async => [_job()],
          loadForJob: (_) async => [
            Application.fromJson(_appJson('alice', 'SHORTLISTED')),
          ],
          loadBooked: (_) async => [],
          sendInvite: (_, __) async => throw const ApiException(
            statusCode: 400,
            message: 'Invalid application.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pickAvailableSlot(tester);
    await tester.tap(find.text('Alice'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send invite'));
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid application.'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets(
    '390px schedule layout keeps week, candidates, and invite usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleInterviewScreen(
            jobId: 'job-1',
            loadJobs: () async => [_job()],
            loadForJob: (_) async => [
              Application.fromJson(_appJson('alice', 'SHORTLISTED')),
            ],
            loadBooked: (_) async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Send invite'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
