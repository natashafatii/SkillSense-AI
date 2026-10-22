import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/models/application.dart';
import 'package:skillsense_ai/models/interview.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/screens/hr/schedule_interview_screen.dart';
import 'package:skillsense_ai/models/question_set.dart';
import 'package:skillsense_ai/models/voice/voice_contract.dart';
import 'package:skillsense_ai/services/api_exception.dart';
import 'package:skillsense_ai/services/application_service.dart';
import 'package:skillsense_ai/services/interview_service.dart';
import 'package:skillsense_ai/services/question_preparation_service.dart';
import 'package:skillsense_ai/services/voice/voice_lifecycle_backend.dart';
import 'package:skillsense_ai/widgets/question_preparation_panel.dart';
import 'package:skillsense_ai/screens/application_screening_screen.dart';

Map<String, dynamic> applicationJson({
  String stage = 'UNDER_REVIEW',
  int version = 4,
  String processing = 'SUCCEEDED',
  String eligibility = 'UNKNOWN',
  String outcome = 'UNDER_REVIEW',
  double? score = 90,
  List<String> actions = const ['shortlist', 'reject', 'rescreen'],
}) => {
  'id': 'application-1',
  'candidate': 'candidate-profile-1',
  'candidate_email': 'candidate@example.test',
  'candidate_name': 'Candidate',
  'job': 'job-1',
  'job_title': 'Engineer',
  'status': stage,
  'version': version,
  'created_at': '2026-10-22T08:00:00Z',
  'updated_at': null,
  'match_score': score,
  'eligible_for_interview': stage == 'SHORTLISTED',
  'allowed_actions': actions,
  'assessment': {
    'id': 'assessment-1',
    'revision': 2,
    'status': processing,
    'match_score': score,
    'threshold': '70.0',
    'policy_version': '7',
    'eligibility': eligibility,
    'outcome': outcome,
    'criteria_results': [
      {
        'kind': 'experience',
        'requirement': '3 years',
        'status': eligibility,
        'evidence': 'Employment duration not verified',
      },
    ],
    'reasons': ['REQUIREMENT_UNVERIFIED'],
    'matched_skills': ['Dart'],
    'missing_skills': [],
    'attempts': 1,
    'recovery_action': processing == 'FAILED' ? 'REPLACE_RESUME' : 'WAIT',
    'completed_at': null,
  },
};
Map<String, dynamic> question(
  String id,
  String text,
  int position, {
  String source = 'MANUAL',
}) => {
  'id': id,
  'text': text,
  'position': position,
  'category': 'TECHNICAL',
  'source': source,
};
Map<String, dynamic> setJson({
  int revision = 8,
  String state = 'READY',
  bool approved = false,
  bool frozen = false,
  bool legacy = false,
  List<Map<String, dynamic>>? questions,
}) => {
  'id': 'set-1',
  'application': 'application-1',
  'assessment': 'assessment-1',
  'assessment_revision': 2,
  'revision': revision,
  'generation_status': state,
  'approved_at': approved ? '2026-10-22T08:00:00Z' : null,
  'frozen_at': frozen ? '2026-10-22T09:00:00Z' : null,
  'legacy': legacy,
  'questions': questions ?? [question('q-1', 'Manual wording', 0)],
};
Map<String, dynamic> interviewJson({
  DateTime? scheduledAt,
  bool canStart = true,
  String workflow = 'SCHEDULED',
}) => {
  'id': 'interview-1',
  'application': 'application-1',
  'status': 'SCHEDULED',
  'workflow_state': workflow,
  'scheduled_at': (scheduledAt ?? DateTime.now().add(const Duration(days: 2)))
      .toUtc()
      .toIso8601String(),
  'completed_at': null,
  'question_readiness': {
    'state': 'READY',
    'approved_question_count': 1,
    'can_start': canStart,
  },
};
Dio mockClient(void Function(RequestOptions, RequestInterceptorHandler) route) {
  final client = Dio();
  client.interceptors.add(InterceptorsWrapper(onRequest: route));
  return client;
}

void respond(
  RequestOptions request,
  RequestInterceptorHandler handler,
  Object? data, {
  int status = 200,
}) => handler.resolve(
  Response(requestOptions: request, data: data, statusCode: status),
);
void reject(
  RequestOptions request,
  RequestInterceptorHandler handler,
  int status,
) => handler.reject(
  DioException(
    requestOptions: request,
    response: Response(
      requestOptions: request,
      statusCode: status,
      data: {'detail': 'Review required'},
    ),
  ),
);
Future<void> mountPanel(
  WidgetTester tester,
  Dio client, {
  Application? application,
  void Function(String?, int?)? approval,
}) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionPreparationPanel(
            applicationId: 'application-1',
            application: application,
            client: client,
            onApprovalChanged: approval ?? (_, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
    'screening zero/null, unknown evidence and recommendation remain separate from applied stage',
    () {
      final app = Application.fromJson(
        applicationJson(stage: 'UNDER_REVIEW', score: 0, outcome: 'REJECTED'),
      );
      expect(app.resumeScore, 0);
      expect(app.screening!.matchScore, 0);
      expect(app.screening!.threshold, 70);
      expect(app.screening!.eligibility, 'UNKNOWN');
      expect(app.screening!.outcome, 'REJECTED');
      expect(app.status, ApplicationStatus.underReview);
      expect(
        app.screening!.criteria.single.evidence,
        'Employment duration not verified',
      );
      final missing = Application.fromJson({
        ...applicationJson(score: null),
        'score': 99,
      });
      expect(missing.resumeScore, null);
    },
  );
  test(
    'all new application stages parse without a locally inferred next stage',
    () {
      for (final stage in [
        'SCHEDULED',
        'IN_PROGRESS',
        'INTERVIEW_FAILED',
        'SCREENED',
      ]) {
        final status = ApplicationStatus.fromString(stage);
        expect(status, isNot(ApplicationStatus.unknown));
        expect(status.nextStatus, null);
      }
    },
  );
  test(
    'recruiter list and summary require job, with workflow filters and endpoint pagination',
    () async {
      var calls = 0;
      final client = mockClient((r, h) {
        calls++;
        expect(r.queryParameters['job'], 'job-1');
        if (r.path.endsWith('summary/')) {
          respond(r, h, {
            'total': 1,
            'by_status': {'UNDER_REVIEW': 1},
            'by_processing_status': {'SUCCEEDED': 1},
          });
        } else {
          expect(r.queryParameters['page_size'], 20);
          expect(r.queryParameters['eligibility'], 'UNKNOWN');
          expect(r.queryParameters['eligible_for_interview'], 'false');
          expect(r.queryParameters['min_match_score'], 70);
          respond(r, h, {
            'count': 1,
            'next': null,
            'previous': null,
            'results': [applicationJson()],
          });
        }
      });
      await expectLater(
        ApplicationService.listApplications(client: client, role: 'RECRUITER'),
        throwsArgumentError,
      );
      await expectLater(
        ApplicationService.summary(client: client, role: 'RECRUITER'),
        throwsArgumentError,
      );
      expect(calls, 0);
      final page = await ApplicationService.listApplications(
        client: client,
        role: 'RECRUITER',
        jobId: 'job-1',
        pageSize: 20,
        eligibility: 'UNKNOWN',
        eligibleForInterview: false,
        minMatchScore: 70,
      );
      expect(page.results.single.job, 'job-1');
      expect(
        (await ApplicationService.summary(
          client: client,
          role: 'RECRUITER',
          jobId: 'job-1',
        )).total,
        1,
      );
    },
  );
  test(
    'screening actions use the reviewed application version and explicit reasons',
    () async {
      final app = Application.fromJson(applicationJson());
      final client = mockClient((r, h) {
        expect(r.method, 'POST');
        expect(r.data, {
          'expected_version': 4,
          'reason': 'Reviewed qualification evidence.',
        });
        respond(
          r,
          h,
          applicationJson(stage: 'SHORTLISTED', version: 5, actions: []),
        );
      });
      expect(
        (await ApplicationService.screeningAction(
          app,
          'shortlist',
          reason: 'Reviewed qualification evidence.',
          client: client,
        )).version,
        5,
      );
      await expectLater(
        ApplicationService.screeningAction(app, 'reject', client: client),
        throwsArgumentError,
      );
      await expectLater(
        ApplicationService.screeningAction(app, 'anything', client: client),
        throwsStateError,
      );
    },
  );
  test(
    'retry replacement sends new resume and boolean consent only on retry',
    () async {
      final app = Application.fromJson(
        applicationJson(processing: 'FAILED', actions: ['retry-screening']),
      );
      final client = mockClient((r, h) {
        expect(r.path, '/applications/application-1/retry-screening/');
        expect(r.data, {
          'expected_version': 4,
          'resume_id': 'new-resume',
          'consent_given': true,
        });
        respond(
          r,
          h,
          applicationJson(processing: 'QUEUED', version: 5, actions: []),
          status: 202,
        );
      });
      final result = await ApplicationService.screeningAction(
        app,
        'retry-screening',
        resumeId: 'new-resume',
        consent: true,
        client: client,
      );
      expect(result.screening!.pending, true);
      await expectLater(
        ApplicationService.screeningAction(
          app,
          'retry-screening',
          resumeId: 'new-resume',
          client: client,
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'rescreen is distinct and does not send shortlist/reject fields',
    () async {
      final client = mockClient((r, h) {
        expect(r.path, endsWith('/rescreen/'));
        expect(r.data, {'expected_version': 4});
        respond(
          r,
          h,
          applicationJson(processing: 'QUEUED', version: 5),
          status: 202,
        );
      });
      final result = await ApplicationService.screeningAction(
        Application.fromJson(applicationJson()),
        'rescreen',
        client: client,
      );
      expect(result.status, ApplicationStatus.underReview);
      expect(result.screening!.pending, true);
    },
  );
  test(
    'application submission with an existing resume uses JSON consent',
    () async {
      final client = mockClient((r, h) {
        expect(r.data, isA<Map>());
        expect(r.data['consent_given'], true);
        expect(r.data['resume_id'], 'new-resume');
        respond(r, h, applicationJson(), status: 201);
      });
      await ApplicationService.submitApplication(
        jobId: 'job-1',
        resumeId: 'new-resume',
        consentGiven: true,
        client: client,
      );
    },
  );
  test(
    'explicit preparation uses application version without creating an interview',
    () async {
      final client = mockClient((r, h) {
        expect(r.path, '/applications/application-1/question-set/');
        expect(r.data, {'expected_version': 4});
        respond(r, h, setJson(state: 'QUEUED', questions: []), status: 202);
      });
      final result = await QuestionPreparationService(
        client: client,
      ).prepare(Application.fromJson(applicationJson(stage: 'SHORTLISTED')));
      expect(result.generationStatus, 'QUEUED');
    },
  );
  test(
    'all question commands carry exact expected_revision and the documented command fields',
    () async {
      for (final entry in <String, Map<String, dynamic>>{
        'add': {'text': 'Manual wording', 'category': 'TECHNICAL'},
        'edit': {
          'id': 'q-1',
          'text': 'Edited wording',
          'category': 'SITUATIONAL',
        },
        'remove': {'id': 'q-1'},
        'reorder': {
          'ids': ['q-1'],
        },
        'approve': {},
        'regenerate': {},
      }.entries) {
        final client = mockClient((r, h) {
          expect(r.path, '/question-sets/set-1/');
          expect(r.method, 'PATCH');
          expect(r.data, {
            ...entry.value,
            'operation': entry.key,
            'expected_revision': 8,
          });
          respond(r, h, setJson(revision: 9));
        });
        final result = await QuestionPreparationService(
          client: client,
        ).command(QuestionSet.fromJson(setJson()), entry.key, entry.value);
        expect(result.revision!.value, 9);
      }
    },
  );
  test(
    'failed generation retry is explicit; frozen/legacy/approved regeneration and empty approval block',
    () async {
      var calls = 0;
      final client = mockClient((r, h) {
        calls++;
        expect(r.data, {'operation': 'retry', 'expected_revision': 8});
        respond(r, h, setJson(revision: 9, state: 'QUEUED', questions: []));
      });
      final service = QuestionPreparationService(client: client);
      expect(
        (await service.command(
          QuestionSet.fromJson(setJson(state: 'FAILED', questions: [])),
          'retry',
        )).generationStatus,
        'QUEUED',
      );
      for (final json in [setJson(frozen: true), setJson(legacy: true)]) {
        await expectLater(
          service.command(QuestionSet.fromJson(json), 'edit', {
            'id': 'q-1',
            'text': 'New',
          }),
          throwsStateError,
        );
      }
      await expectLater(
        service.command(
          QuestionSet.fromJson(setJson(approved: true)),
          'regenerate',
        ),
        throwsStateError,
      );
      await expectLater(
        service.command(
          QuestionSet.fromJson(setJson(questions: [])),
          'approve',
        ),
        throwsStateError,
      );
      await expectLater(
        service.command(QuestionSet.fromJson(setJson()), 'reorder', {
          'ids': ['foreign'],
        }),
        throwsArgumentError,
      );
      expect(calls, 1);
    },
  );
  test(
    'stale set revisions surface 409 without retry or substitution',
    () async {
      var calls = 0;
      final client = mockClient((r, h) {
        calls++;
        expect(r.data['expected_revision'], 8);
        reject(r, h, 409);
      });
      await expectLater(
        QuestionPreparationService(
          client: client,
        ).command(QuestionSet.fromJson(setJson()), 'approve'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      expect(calls, 1);
    },
  );
  test(
    'scheduling submits exact approved revision then refreshes application and interview',
    () async {
      final paths = <String>[];
      final at = DateTime.now().add(const Duration(days: 2));
      final client = mockClient((r, h) {
        paths.add('${r.method} ${r.path}');
        if (r.method == 'POST') {
          expect(r.data, {
            'application': 'application-1',
            'scheduled_at': at.toUtc().toIso8601String(),
            'question_set': 'set-1',
            'expected_revision': 8,
          });
          respond(r, h, interviewJson(scheduledAt: at), status: 201);
        } else if (r.path.startsWith('/applications/')) {
          respond(r, h, applicationJson(stage: 'SCHEDULED', version: 5));
        } else {
          respond(r, h, interviewJson(scheduledAt: at));
        }
      });
      final result = await InterviewService.schedule(
        applicationId: 'application-1',
        scheduledAt: at,
        questionSetId: 'set-1',
        expectedRevision: 8,
        client: client,
      );
      expect(result.workflowState, 'SCHEDULED');
      expect(paths, [
        'POST /interviews/',
        'GET /applications/application-1/',
        'GET /interviews/interview-1/',
      ]);
      await expectLater(
        InterviewService.schedule(
          applicationId: 'application-1',
          scheduledAt: at,
          client: client,
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test('stale scheduling cannot silently schedule a newer revision', () async {
    var calls = 0;
    final client = mockClient((r, h) {
      calls++;
      expect(r.data['expected_revision'], 8);
      reject(r, h, 409);
    });
    await expectLater(
      InterviewService.schedule(
        applicationId: 'application-1',
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
        questionSetId: 'set-1',
        expectedRevision: 8,
        client: client,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });
  test(
    'role-selected candidate DTO ignores private keys and lobby parses without questions',
    () {
      final safe = CandidateInterviewData.fromJson(
        interviewJson(),
        interviewId: 'interview-1',
      );
      expect(safe.interview.questionReadiness.state, 'READY');
      final row = {
        ...interviewJson(),
        'questions': [
          {'malformed': 'private'},
        ],
        'question_fallback_reason': 'Private generation error',
      };
      expect(Interview.forRole(row, 'CANDIDATE'), isA<CandidateInterview>());
      expect(Interview.forRole(row, 'CANDIDATE').questionFallbackReason, '');
      final recruiter =
          Interview.forRole({
                ...interviewJson(),
                'questions': [
                  {
                    'id': 'frozen-q',
                    'text': 'Private wording',
                    'approved': true,
                  },
                ],
              }, 'RECRUITER')
              as RecruiterInterview;
      expect(recruiter.questions.single.id, 'frozen-q');
    },
  );
  test(
    'future joining time, server can_start and unknown workflow all gate joining',
    () {
      final now = DateTime.now(),
          at = DateTime.now().add(const Duration(hours: 1));
      expect(
        Interview.fromJson(interviewJson(scheduledAt: at)).canJoinAt(now),
        false,
      );
      expect(
        Interview.fromJson(
          interviewJson(scheduledAt: at),
        ).canJoinAt(at.subtract(const Duration(minutes: 15))),
        true,
      );
      expect(
        Interview.fromJson(
          interviewJson(scheduledAt: now, canStart: false),
        ).canJoinAt(now),
        false,
      );
      expect(
        Interview.fromJson(
          interviewJson(scheduledAt: now, workflow: 'FUTURE'),
        ).canJoinAt(now),
        false,
      );
    },
  );
  test(
    'candidate start rejection is shown without following with another provider request',
    () async {
      var calls = 0;
      final client = mockClient((r, h) {
        calls++;
        reject(r, h, 403);
      });
      final backend = VoiceLifecycleBackend(
        contractConfirmed: true,
        client: () async => client,
      );
      await expectLater(
        backend.start('interview-1', videoRequired: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      expect(calls, 1);
    },
  );
  testWidgets(
    'editor invalidates approval on edit, preserves manual wording, and sends category',
    (tester) async {
      var current = setJson(approved: true);
      final patches = <Map>[];
      String? selected;
      int? revision;
      final client = mockClient((r, h) {
        if (r.method == 'GET') {
          respond(r, h, current);
          return;
        }
        final body = Map<String, dynamic>.from(r.data as Map);
        patches.add(body);
        expect(body['operation'], 'edit');
        expect(body['expected_revision'], 8);
        expect(body['text'], 'Reviewed manual wording');
        expect(body['category'], 'TECHNICAL');
        current = setJson(
          revision: 9,
          questions: [question('q-1', 'Reviewed manual wording', 0)],
        );
        respond(r, h, current);
      });
      await mountPanel(
        tester,
        client,
        approval: (id, rev) {
          selected = id;
          revision = rev;
        },
      );
      expect(selected, 'set-1');
      expect(revision, 8);
      await tester.tap(find.byTooltip('Edit question 1'));
      await tester.pumpAndSettle();
      expect(find.text('Manual wording'), findsWidgets);
      await tester.enterText(
        find.byType(TextFormField),
        'Reviewed manual wording',
      );
      await tester.tap(find.text('Save question'));
      await tester.pumpAndSettle();
      expect(patches.length, 1);
      expect(selected, null);
      expect(find.text('Reviewed manual wording'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'regeneration requires deliberate confirmation and retains returned manual wording',
    (tester) async {
      var patches = 0;
      var current = setJson(state: 'FALLBACK');
      final client = mockClient((r, h) {
        if (r.method == 'GET') {
          respond(r, h, current);
        } else {
          patches++;
          expect(r.data['operation'], 'regenerate');
          current = setJson(revision: 9);
          respond(r, h, current);
        }
      });
      await mountPanel(tester, client);
      await tester.tap(find.text('Regenerate unapproved draft'));
      await tester.pumpAndSettle();
      expect(patches, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(patches, 0);
      await tester.tap(find.text('Regenerate unapproved draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate draft'));
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(find.text('Manual wording'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'candidate screening renders unknown evidence and recommendation without recruiter actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ApplicationScreeningScreen(
            applicationId: 'application-1',
            roleProvider: () => 'CANDIDATE',
            loadApplication: (_) async =>
                Application.fromJson(applicationJson(outcome: 'REJECTED')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Policy recommendation: REJECTED'), findsOneWidget);
      expect(
        find.text('Eligibility: UNKNOWN — requires review'),
        findsOneWidget,
      );
      expect(find.text('Application: UNDER REVIEW'), findsOneWidget);
      expect(find.text('Shortlist'), findsNothing);
      expect(find.byType(QuestionPreparationPanel), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'recruiter review, editor approval and scheduling compose without drafting an interview',
    () async {
      var call = 0;
      final at = DateTime.now().add(const Duration(days: 2));
      final client = mockClient((r, h) {
        switch (call++) {
          case 0:
            expect(r.path, '/applications/application-1/shortlist/');
            expect(r.data['expected_version'], 4);
            respond(
              r,
              h,
              applicationJson(stage: 'SHORTLISTED', version: 5, actions: []),
            );
          case 1:
            expect(r.path, '/applications/application-1/question-set/');
            expect(r.method, 'GET');
            respond(r, h, setJson());
          case 2:
            expect(r.path, '/question-sets/set-1/');
            expect(r.data['expected_revision'], 8);
            expect(r.data['operation'], 'edit');
            respond(
              r,
              h,
              setJson(
                revision: 9,
                questions: [
                  question('q-1', 'Distinctive reviewed manual wording', 0),
                ],
              ),
            );
          case 3:
            expect(r.data, {'operation': 'approve', 'expected_revision': 9});
            respond(
              r,
              h,
              setJson(
                revision: 10,
                approved: true,
                questions: [
                  question('q-1', 'Distinctive reviewed manual wording', 0),
                ],
              ),
            );
          case 4:
            expect(r.path, '/interviews/');
            expect(r.data['expected_revision'], 10);
            expect(r.data['question_set'], 'set-1');
            respond(r, h, interviewJson(scheduledAt: at), status: 201);
          case 5:
            expect(r.path, '/applications/application-1/');
            respond(
              r,
              h,
              applicationJson(stage: 'SCHEDULED', version: 6, actions: []),
            );
          case 6:
            expect(r.path, '/interviews/interview-1/');
            respond(r, h, {
              ...interviewJson(scheduledAt: at),
              'questions': [
                {
                  'id': 'frozen-q-1',
                  'text': 'Distinctive reviewed manual wording',
                  'approved': true,
                },
              ],
            });
          default:
            fail('Unexpected request ${r.method} ${r.path}');
        }
      });
      final shortlisted = await ApplicationService.screeningAction(
        Application.fromJson(applicationJson()),
        'shortlist',
        reason: 'Reviewed evidence.',
        client: client,
      );
      expect(shortlisted.canPrepareQuestions, true);
      final preparation = QuestionPreparationService(client: client);
      final draft = await preparation.read(shortlisted.id);
      final edited = await preparation.command(draft, 'edit', {
        'id': 'q-1',
        'text': 'Distinctive reviewed manual wording',
      });
      final approved = await preparation.command(edited, 'approve');
      expect(approved.schedulable, true);
      final scheduled = await InterviewService.schedule(
        applicationId: shortlisted.id,
        scheduledAt: at,
        questionSetId: approved.id,
        expectedRevision: approved.revision!.value,
        client: client,
      );
      expect(
        (scheduled as RecruiterInterview).questions.single.id,
        'frozen-q-1',
      );
      expect(call, 7);
      final safe = CandidateInterviewData.fromJson(
        interviewJson(scheduledAt: at),
        interviewId: scheduled.id,
      );
      expect(safe.interview.workflowState, 'SCHEDULED');
    },
  );

  testWidgets(
    'scheduler Send invite stays disabled until the selected draft is approved',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = Application.fromJson(applicationJson(stage: 'SHORTLISTED'));
      var current = setJson(), sends = 0;
      final client = mockClient((r, h) {
        if (r.method == 'GET') {
          respond(r, h, current);
        } else {
          expect(r.data, {'operation': 'approve', 'expected_revision': 8});
          current = setJson(revision: 9, approved: true);
          respond(r, h, current);
        }
      });
      final job = Job(
        id: 'job-1',
        recruiter: 'recruiter-1',
        recruiterCompany: 'Company',
        title: 'Engineer',
        description: 'Role',
        requirements: 'Dart',
        skillsRequired: const ['Dart'],
        location: 'Remote',
        jobType: JobType.remote,
        experienceLevel: ExperienceLevel.mid,
        status: JobStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        jobSkills: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleInterviewScreen(
            jobId: 'job-1',
            applicationId: app.id,
            questionClient: client,
            loadJobs: () async => [job],
            loadForJob: (_) async => [app],
            loadBooked: (_) async => [],
            loadApplication: (_) async => app,
            sendInvite: (id, time, set, revision) async {
              sends++;
              expect(set, 'set-1');
              expect(revision, 9);
              return Interview(
                id: 'interview-1',
                applicationId: id,
                scheduledAt: time,
                workflowState: 'SCHEDULED',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slot = find
          .byWidgetPredicate((w) => w is ChoiceChip && w.onSelected != null)
          .first;
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send invite'),
            )
            .onPressed,
        null,
      );
      final approve = find.text('Approve this set');
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send invite'),
            )
            .onPressed,
        isNotNull,
      );
      final send = find.text('Send invite');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'screening conflict preserves reason and requires review before a new version is submitted',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reads = 0;
      final versions = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ApplicationScreeningScreen(
            applicationId: 'application-1',
            roleProvider: () => 'RECRUITER',
            loadApplication: (_) async => Application.fromJson(
              applicationJson(version: ++reads == 1 ? 4 : 6),
            ),
            performAction: (app, action, reason) async {
              versions.add(app.version);
              expect(reason, 'Reviewed uncertain employment evidence.');
              if (versions.length == 1) {
                throw const ApiException(
                  statusCode: 409,
                  message: 'Stale evidence',
                );
              }
              return Application.fromJson(applicationJson(version: 7));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reason = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText ==
                'Reason for rejection or screening override',
      );
      await tester.enterText(reason, 'Reviewed uncertain employment evidence.');
      await tester.tap(find.text('Shortlist'));
      await tester.pumpAndSettle();
      expect(versions, [4]);
      expect(
        tester.widget<TextField>(reason).controller!.text,
        'Reviewed uncertain employment evidence.',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Shortlist'),
            )
            .onPressed,
        null,
      );
      await tester.tap(find.text('I reviewed the refreshed application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shortlist'));
      await tester.pumpAndSettle();
      expect(versions, [4, 6]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'ordering and archive commands retain the active question IDs and invalidate approval',
    (tester) async {
      var current = setJson(
        approved: true,
        questions: [
          question('q-1', 'First manual wording', 0),
          question('q-2', 'Second manual wording', 1),
        ],
      );
      final bodies = <Map>[];
      String? approved;
      final client = mockClient((r, h) {
        if (r.method == 'GET') {
          respond(r, h, current);
          return;
        }
        final body = Map<String, dynamic>.from(r.data as Map);
        bodies.add(body);
        if (body['operation'] == 'reorder') {
          expect(body, {
            'operation': 'reorder',
            'expected_revision': 8,
            'ids': ['q-2', 'q-1'],
          });
          current = setJson(
            revision: 9,
            questions: [
              question('q-2', 'Second manual wording', 0),
              question('q-1', 'First manual wording', 1),
            ],
          );
        } else {
          expect(body, {
            'operation': 'remove',
            'expected_revision': 9,
            'id': 'q-1',
          });
          current = setJson(
            revision: 10,
            questions: [question('q-2', 'Second manual wording', 0)],
          );
        }
        respond(r, h, current);
      });
      await mountPanel(tester, client, approval: (id, _) => approved = id);
      expect(approved, 'set-1');
      await tester.tap(find.byTooltip('Move question 2 up'));
      await tester.pumpAndSettle();
      expect(approved, null);
      await tester.tap(find.byTooltip('Remove question 2'));
      await tester.pumpAndSettle();
      expect(bodies.length, 2);
      expect(find.text('First manual wording'), findsNothing);
      expect(find.text('Second manual wording'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'legacy question set is labelled read-only and cannot enable scheduling',
    (tester) async {
      final client = mockClient(
        (r, h) => respond(
          r,
          h,
          setJson(state: 'LEGACY', legacy: true, approved: true),
        ),
      );
      String? approved;
      await mountPanel(tester, client, approval: (id, _) => approved = id);
      expect(approved, null);
      expect(
        find.textContaining('Historical imported questions'),
        findsOneWidget,
      );
      expect(find.text('Approve this set'), findsNothing);
      expect(find.byTooltip('Edit question 1'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'late question response is discarded after switching applications',
    (tester) async {
      final delayed = Completer<void>();
      var application = 'application-1';
      late StateSetter update;
      final client = mockClient((r, h) {
        if (r.path.contains('application-1')) {
          delayed.future.then(
            (_) => respond(
              r,
              h,
              setJson(
                questions: [
                  question('old', 'Old application private wording', 0),
                ],
              ),
            ),
          );
        } else {
          respond(r, h, {
            ...setJson(
              questions: [question('new', 'Current application wording', 0)],
            ),
            'application': 'application-2',
          });
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return QuestionPreparationPanel(
                    applicationId: application,
                    client: client,
                    onApprovalChanged: (_, _) {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      update(() => application = 'application-2');
      await tester.pumpAndSettle();
      expect(find.text('Current application wording'), findsOneWidget);
      delayed.complete();
      await tester.pumpAndSettle();
      expect(find.text('Old application private wording'), findsNothing);
      expect(find.text('Current application wording'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'failed generation stays failed until explicit retry and then renders queued',
    (tester) async {
      var current = setJson(state: 'FAILED', questions: []),
          reads = 0,
          posts = 0;
      final client = mockClient((r, h) {
        if (r.method == 'GET') {
          reads++;
          respond(r, h, current);
        } else {
          posts++;
          expect(r.data, {'operation': 'retry', 'expected_revision': 8});
          current = setJson(state: 'QUEUED', revision: 9, questions: []);
          respond(r, h, current);
        }
      });
      await mountPanel(tester, client);
      expect(find.text('Retry generation'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(posts, 0);
      expect(reads, 1);
      await tester.tap(find.text('Retry generation'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Question generation is queued.'), findsOneWidget);
      expect(find.text('Approve this set'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
