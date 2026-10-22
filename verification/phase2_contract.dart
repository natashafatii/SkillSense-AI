import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/recruitment_evidence.dart';
import 'package:skillsense_ai/services/recruitment_review_controller.dart';
import 'package:skillsense_ai/services/recruitment_workflow_service.dart';
import 'package:skillsense_ai/services/session_scope.dart';

Json app({int version = 7}) => {
  'id': 'app',
  'candidate': 'profile',
  'candidate_email': 'test@example.test',
  'job': 'job',
  'job_title': 'Engineer',
  'status': 'INTERVIEWED',
  'version': version,
  'created_at': '2026-10-22T08:00:00Z',
};
Json interview({String id = 'interview', String status = 'DONE'}) => {
  'id': id,
  'application': 'app',
  'status': status,
  'workflow_state': 'EVALUATED',
  'completion_outcome': 'USABLE',
  'evaluation_status': 'READY',
  'completed_at': '2026-10-22T09:00:00Z',
  'questions': [
    {'id': 'frozen-q', 'text': 'Frozen wording', 'approved': true},
  ],
};
Json transcript(String id, int number, String hash) => {
  'id': id,
  'number': number,
  'source': 'provider',
  'content_hash': hash,
  'text': 'Hi 😀 yes',
  'created_at': '2026-10-22T08:00:00Z',
  'turns': [
    {'id': 'turn', 'role': 'user', 'text': 'Hi 😀 yes'},
  ],
};
Json evaluation({
  String id = 'evaluation',
  String status = 'READY',
  String hash = 'old-hash',
  Object? extraction,
}) => {
  'id': id,
  'revision': 3,
  'status': status,
  'score': '0.0',
  'coverage': '1.0',
  'published_at': status == 'READY' ? '2026-10-22T09:00:00Z' : null,
  'transcript_revision': 1,
  'transcript_hash': hash,
  'context_hash': 'context',
  'contract_version': extraction == null ? 'answers-v1' : 'answers-v2',
  'model_name': 'server-model',
  'attempts': 1,
  'run_number': 2,
  'extraction': extraction,
  'answers': [
    {
      'question_id': 'frozen-q',
      'status': 'ANSWERED',
      'criteria': {'technical': '0.0', 'missing': null},
      'strengths': [],
      'gaps': [],
      'rationale': 'Server rationale',
      'evidence': [
        {'turn_id': 'turn', 'quote': 'yes'},
      ],
      'uncertainty': 0.2,
    },
  ],
};
Json score({String status = 'COMPLETE', String eval = 'evaluation'}) => {
  'status': status,
  'score_revision': 'score',
  'revision': 2,
  'combined_recommendation_percentage': '0.0',
  'screening_match_percentage': '60.25',
  'interview_performance_percentage': 0,
  'coverage': '1',
  'answer_coverage': '1',
  'rubric': 'rubric',
  'rubric_version': 4,
  'weights': {'match': '0.4', 'interview': '0.6', 'behavioral': '0'},
  'source_revisions': {
    'evaluation': eval,
    'evaluation_revision': 3,
    'assessment': 'assessment',
    'assessment_revision': 2,
  },
};

class Fixture {
  final dio = Dio();
  final requests = <RequestOptions>[];
  int version = 7;
  bool conflict = false, pending = false, unavailable = false;
  bool hideOldTranscript = false;
  String recoveredId = 'new-interview';
  String completionOutcome = 'USABLE', workflow = 'EVALUATED';
  Fixture() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          requests.add(r);
          if (unavailable && r.method == 'GET') {
            h.reject(
              DioException(
                requestOptions: r,
                response: Response(
                  requestOptions: r,
                  statusCode: 403,
                  data: {'detail': 'Access unavailable'},
                ),
              ),
            );
            return;
          }
          Object? data;
          if (r.method == 'POST') {
            if (conflict) {
              h.reject(
                DioException(
                  requestOptions: r,
                  response: Response(
                    requestOptions: r,
                    statusCode: 409,
                    data: {'detail': 'Stale version'},
                  ),
                ),
              );
              return;
            }
            version++;
            if (r.path.endsWith('/rerun-evaluation/') ||
                r.path.endsWith('/select-transcript/')) {
              pending = true;
            }
            data = r.path.endsWith('/reschedule/')
                ? interview()
                : r.path.endsWith('/reopen/')
                ? interview(id: recoveredId, status: 'SCHEDULED')
                : <String, dynamic>{};
          } else if (r.path == '/applications/app/') {
            data = app(version: version);
          } else if (r.path == '/interviews/') {
            data = [
              interview()
                ..['completion_outcome'] = completionOutcome
                ..['workflow_state'] = workflow,
              interview(id: 'older'),
            ];
          } else if (r.path.endsWith('/scoring/')) {
            data = {'current': score(), 'history': []};
          } else if (r.path.endsWith('/workflow-history/')) {
            data = {'actions': []};
          } else if (r.path.endsWith('/transcript-revisions/')) {
            data = {
              'selected_revision': 'new',
              'selection_version': 9,
              'selection_pinned': true,
              'revisions': [
                transcript('new', 2, 'new-hash'),
                if (!hideOldTranscript) transcript('old', 1, 'old-hash'),
              ],
            };
          } else if (r.path.endsWith('/evaluations/')) {
            data = {
              'transcript': {'state': 'READY'},
              'evaluations': [
                evaluation(status: pending ? 'PROCESSING' : 'READY'),
              ],
            };
          } else if (r.path.endsWith('/feedback-review/')) {
            data = {'reports': []};
          } else if (r.path.endsWith('/ranking/')) {
            data = {
              'count': 2,
              'next': null,
              'previous': null,
              'results': [
                {
                  'id': 'server-first',
                  'candidate': 'profile',
                  'candidate_name': 'First',
                  'final_score': null,
                  'score_status': 'INCOMPLETE',
                },
                {
                  'id': 'server-second',
                  'candidate': 'profile-2',
                  'final_score': '0.0',
                  'score_status': 'COMPLETE',
                },
              ],
            };
          } else {
            throw StateError('Unexpected test request ${r.path}');
          }
          h.resolve(Response(requestOptions: r, statusCode: 200, data: data));
        },
      ),
    );
  }
  RecruitmentWorkflowService get service => RecruitmentWorkflowService(
    client: () async => dio,
    role: () => 'RECRUITER',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a delayed client cannot send a command after the account changes',
    () async {
      final f = Fixture();
      final r = await f.service.review('app');
      final ready = Completer<Dio>();
      final service = RecruitmentWorkflowService(
        client: () => ready.future,
        role: () => 'RECRUITER',
      );
      final command = service.decide(r, 'HIRE', 'Reviewed evidence');
      SessionScope.invalidate();
      ready.complete(f.dio);
      await expectLater(command, throwsStateError);
      expect(f.requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  test('access denial clears previously visible private evidence', () async {
    final f = Fixture();
    final c = RecruitmentReviewController('app', service: f.service);
    await c.refresh(poll: false);
    expect(c.review, isNotNull);
    f.unavailable = true;
    await c.refresh(poll: false);
    expect(c.review, isNull);
    expect(c.currentScore, isNull);
    expect(c.canCommand, isFalse);
    c.dispose();
  });
  test(
    'missing application concurrency version never authorizes commands',
    () async {
      final f = Fixture()..version = 0;
      final c = RecruitmentReviewController('app', service: f.service);
      await c.refresh(poll: false);
      expect(c.canCommand, isFalse);
      c.dispose();
    },
  );
  test(
    'evaluation evidence remains on frozen number AND hash after selection changes',
    () {
      final h = TranscriptHistory.fromJson({
        'selected_revision': 'new',
        'selection_version': 9,
        'revisions': [
          transcript('new', 2, 'new-hash'),
          transcript('old', 1, 'old-hash'),
        ],
      });
      final e = EvaluationRevision.fromJson(evaluation());
      expect(e.frozenTranscript(h)!.id, 'old');
      expect(e.extraction, isNull);
      expect(e.answers.single.criteria['technical'], 0);
      expect(e.answers.single.criteria['missing'], isNull);
      expect(
        EvaluationRevision.fromJson(
          evaluation(hash: 'mismatch'),
        ).frozenTranscript(h),
        isNull,
      );
    },
  );
  test(
    'answers-v2 keeps attribution, followups, unmatched turns and optional timing',
    () {
      final e = EvaluationRevision.fromJson(
        evaluation(
          extraction: {
            'questions': [
              {
                'question_id': 'frozen-q',
                'state': 'PARTIAL',
                'confidence': '0.75',
                'method': 'SEMANTIC',
                'asked_turn_id': null,
                'answer_turn_ids': ['turn'],
                'follow_up_turn_ids': ['followup'],
                'spans': [
                  {
                    'turn_id': 'turn',
                    'start_offset': 3,
                    'end_offset': 4,
                    'start_seconds': null,
                    'end_seconds': null,
                  },
                ],
              },
            ],
            'unmatched_turn_ids': ['other'],
          },
        ),
      );
      final a = e.extraction!.questions.single;
      final turn = TranscriptTurn.fromJson({
        'id': 'turn',
        'role': 'user',
        'text': 'Hi 😀 yes',
      });
      expect(a.spans.single.textIn(turn), '😀');
      expect(a.spans.single.startSeconds, isNull);
      expect(a.followUpTurnIds, ['followup']);
      expect(e.extraction!.unmatchedTurnIds, ['other']);
      expect(a.confidence, .75);
    },
  );
  test(
    'score zero survives decimal parsing; incomplete/unknown scores are never published',
    () {
      expect(ServerScore.fromJson(score()).publishedCombined, 0);
      expect(ServerScore.fromJson(score()).match, 60.25);
      for (final state in [
        'INCOMPLETE',
        'PENDING',
        'QUEUED',
        'PROCESSING',
        'FAILED',
        'STALE',
        'LEGACY',
        'FUTURE',
      ]) {
        expect(
          ServerScore.fromJson(score(status: state)).publishedCombined,
          isNull,
        );
      }
      expect(
        ServerScore.fromJson({'status': 'COMPLETE'}).publishedCombined,
        isNull,
      );
      expect(
        () => ServerScore.fromJson(score()..['coverage'] = '1.5'),
        throwsFormatException,
      );
    },
  );
  test(
    'transcript histories are immutable and capped at the endpoint history window',
    () {
      final h = TranscriptHistory.fromJson({
        'revisions': [transcript('t', 1, 'h')],
      });
      expect(() => h.revisions.clear(), throwsUnsupportedError);
      expect(
        () => TranscriptHistory.fromJson({
          'revisions': List.generate(101, (_) => transcript('t', 1, 'h')),
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'private APIs reject candidate role before making any request',
    () async {
      final f = Fixture();
      final service = RecruitmentWorkflowService(
        client: () async => f.dio,
        role: () => 'CANDIDATE',
      );
      await expectLater(service.review('app'), throwsStateError);
      await expectLater(service.interviews(), throwsStateError);
      expect(f.requests, isEmpty);
    },
  );
  test(
    'review loads each dependency and server ordered attempts without creating a session',
    () async {
      final f = Fixture();
      final r = await f.service.review('app');
      expect(r.application.version, 7);
      expect(r.latestAttempt, isTrue);
      expect(r.normalDecisionReady, isTrue);
      expect(r.transcripts!.version!.value, 9);
      expect(r.latestEvaluation!.revision.value, 3);
      expect(f.requests.every((r) => r.method == 'GET'), isTrue);
      expect(
        f.requests.where((r) => r.path.endsWith('/feedback-review/')),
        hasLength(1),
      );
    },
  );
  test(
    'transcript command uses application and selection versions; rerun uses evaluation revision',
    () async {
      final f = Fixture();
      final r = await f.service.review('app');
      await f.service.selectTranscript(r, 'old', 'Correct source');
      expect(f.requests.last.data, {
        'expected_version': 7,
        'expected_selection_version': 9,
        'transcript_id': 'old',
        'reason': 'Correct source',
      });
      await f.service.rerun(r, 'Manual review');
      expect(f.requests.last.data, {
        'expected_version': 7,
        'expected_revision': 3,
        'reason': 'Manual review',
      });
      expect(
        () => f.service.selectTranscript(r, 'not-owned', 'reason'),
        throwsStateError,
      );
    },
  );
  test(
    'normal decision and explicit override have distinct exact payloads',
    () async {
      final f = Fixture();
      final r = await f.service.review('app');
      await f.service.decide(r, 'HIRE', 'Evidence reviewed');
      expect(f.requests.last.data, {
        'expected_version': 7,
        'outcome': 'HIRE',
        'reason': 'Evidence reviewed',
      });
      await f.service.decide(
        r,
        'REJECT',
        'Decision reason',
        overrideReason: 'Deliberate exception',
      );
      expect(f.requests.last.data, {
        'expected_version': 7,
        'outcome': 'REJECT',
        'reason': 'Decision reason',
        'override': true,
        'override_reason': 'Deliberate exception',
      });
      await f.service.reverse(r, 'Reconsider evidence');
      expect(f.requests.last.data, {
        'expected_version': 7,
        'reason': 'Reconsider evidence',
      });
    },
  );
  test(
    'reschedule keeps identity; reopen changes identity; UTC and exact recovery body',
    () async {
      final f = Fixture();
      final r = await f.service.review('app');
      final time = DateTime.now().add(const Duration(days: 2));
      expect(
        (await f.service.recover(r, time, 'New time', reopen: false)).id,
        'interview',
      );
      expect(f.requests.last.data, {
        'expected_version': 7,
        'scheduled_at': time.toUtc().toIso8601String(),
        'reason': 'New time',
      });
      expect(
        (await f.service.recover(r, time, 'Another attempt', reopen: true)).id,
        'new-interview',
      );
      expect(
        (f.requests.last.data as Map).containsKey('resume_remaining'),
        isFalse,
      );
      f.recoveredId = 'interview';
      await expectLater(
        f.service.recover(r, time, 'Again', reopen: true),
        throwsFormatException,
      );
    },
  );
  test(
    'ranking preserves server order and null; no partial ranking calculation',
    () async {
      final f = Fixture();
      final page = await f.service.ranking('job', 2);
      expect(f.requests.last.queryParameters, {'page': 2});
      expect(page.results.map((r) => r.applicationId), [
        'server-first',
        'server-second',
      ]);
      expect(page.results.first.finalScore, isNull);
      expect(page.results.last.finalScore, 0);
    },
  );
  test(
    'conflict never silently resubmits with refreshed version; deliberate review required',
    () async {
      final f = Fixture();
      final c = RecruitmentReviewController('app', service: f.service);
      await c.refresh(poll: false);
      f.conflict = true;
      f.version = 8;
      final draft = 'Unsaved recruiter reason';
      expect(
        await c.command((r) async {
          await c.service.decide(r, 'HIRE', draft);
        }),
        isFalse,
      );
      expect(c.requiresReview, isTrue);
      expect(c.review!.application.version, 8);
      expect(c.currentScore, isNull);
      expect(f.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(
        (f.requests.firstWhere((r) => r.method == 'POST').data
            as Map)['expected_version'],
        7,
      );
      expect(
        await c.command((r) async {
          await c.service.decide(r, 'HIRE', draft);
        }),
        isFalse,
      );
      await c.refresh(poll: false);
      c.confirmRefreshedReview();
      expect(c.canCommand, isTrue);
      expect(f.requests.where((r) => r.method == 'POST'), hasLength(1));
      c.dispose();
    },
  );
  test(
    'rerun suppresses previous current score and refreshes feedback and application',
    () async {
      final f = Fixture();
      final c = RecruitmentReviewController(
        'app',
        service: f.service,
        isVisible: () => false,
      );
      await c.refresh(poll: false);
      expect(c.currentScore!.publishedCombined, 0);
      expect(
        await c.command((r) async {
          await c.service.rerun(r, 'Correction');
        }),
        isTrue,
      );
      expect(c.currentScore, isNull);
      expect(c.review!.application.version, 8);
      expect(
        f.requests.where((r) => r.path.endsWith('/feedback-review/')),
        hasLength(2),
      );
      c.dispose();
    },
  );
  test('session invalidation clears evidence and pending commands', () async {
    final f = Fixture();
    final c = RecruitmentReviewController('app', service: f.service);
    await c.refresh(poll: false);
    SessionScope.invalidate();
    expect(c.review, isNull);
    expect(c.currentScore, isNull);
    expect(c.canCommand, isFalse);
    c.dispose();
  });
  test(
    'confirmation cannot silently adopt versions refreshed while it was open',
    () async {
      final f = Fixture();
      final c = RecruitmentReviewController('app', service: f.service);
      await c.refresh(poll: false);
      final reviewed = c.review!;
      f.version = 8;
      await c.refresh(poll: false);
      expect(
        await c.command((r) async {
          await c.service.decide(r, 'HIRE', 'Reason');
        }, reviewed: reviewed),
        isFalse,
      );
      expect(c.requiresReview, isTrue);
      expect(f.requests.where((r) => r.method == 'POST'), isEmpty);
      c.dispose();
    },
  );
  test('late refresh cannot replace a newer attempt selection', () async {
    final f = Fixture();
    final c = RecruitmentReviewController('app', service: f.service);
    await c.refresh(poll: false);
    await c.selectAttempt('older');
    expect(c.review!.interview!.id, 'older');
    expect(c.review!.latestAttempt, isFalse);
    expect(c.review!.normalDecisionReady, isFalse);
    c.dispose();
  });
}
