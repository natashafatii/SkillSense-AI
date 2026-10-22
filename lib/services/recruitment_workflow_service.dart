import 'package:dio/dio.dart';
import '../models/api_contract.dart';
import '../models/application.dart';
import '../models/interview.dart';
import '../models/paginated_response.dart';
import '../models/recruitment_evidence.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'session_scope.dart';

class RecruitmentReview {
  final Application application;
  final RecruiterDecision? decision;
  final List<RecruiterInterview> attempts;
  final RecruiterInterview? interview;
  final TranscriptHistory? transcripts;
  final EvaluationHistory? evaluations;
  final ScoreHistory scores;
  final List<WorkflowAction> actions;
  final List<FeedbackReviewRevision> feedback;
  RecruitmentReview({
    required this.application,
    required this.decision,
    required this.attempts,
    required this.interview,
    required this.transcripts,
    required this.evaluations,
    required this.scores,
    required this.actions,
    required this.feedback,
  });
  bool get latestAttempt =>
      interview != null &&
      attempts.isNotEmpty &&
      attempts.first.id == interview!.id;
  EvaluationRevision? get latestEvaluation =>
      evaluations?.revisions.firstOrNull;
  bool get normalDecisionReady =>
      latestAttempt &&
      interview!.status == 'DONE' &&
      interview!.workflowState == 'EVALUATED' &&
      interview!.completedAt != null &&
      interview!.completionOutcome == 'USABLE' &&
      interview!.evaluationStatus == 'READY' &&
      latestEvaluation?.status == 'READY' &&
      latestEvaluation?.publishedAt != null &&
      latestEvaluation?.coverage == 1 &&
      latestEvaluation?.score != null;
  bool get pending =>
      latestEvaluation?.pending == true ||
      scores.current?.pending == true ||
      const {'WAITING'}.contains(evaluations?.transcriptState);
}

/// Recruiter-only, visible-view reads. No provider operations or persistent cache.
class RecruitmentWorkflowService {
  RecruitmentWorkflowService({
    Future<Dio> Function()? client,
    String Function()? role,
  }) : _client = client ?? ApiClient.getInstance,
       _role = role ?? AuthService.getUserRole;
  final Future<Dio> Function() _client;
  final String Function() _role;
  Future<Json> request(
    String path, {
    Json? data,
    CancelToken? cancelToken,
    Json? query,
  }) async {
    if (_role() != 'RECRUITER') throw StateError('Recruiter access required.');
    final generation = SessionScope.generation;
    try {
      final dio = await _client();
      if (generation != SessionScope.generation || _role() != 'RECRUITER') {
        throw StateError('Session changed before the request was sent.');
      }
      final response = await dio.request(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(method: data == null ? 'GET' : 'POST'),
      );
      if (generation != SessionScope.generation || _role() != 'RECRUITER') {
        throw StateError('Session changed.');
      }
      return object(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<RecruiterInterview>> interviews({
    CancelToken? cancelToken,
  }) async {
    if (_role() != 'RECRUITER') throw StateError('Recruiter access required.');
    final generation = SessionScope.generation;
    final dio = await _client();
    final result = <RecruiterInterview>[];
    try {
      for (var page = 1; page <= 100; page++) {
        final r = await dio.get(
          '/interviews/',
          queryParameters: {'page': page},
          cancelToken: cancelToken,
        );
        if (generation != SessionScope.generation || _role() != 'RECRUITER') {
          throw StateError('Session changed.');
        }
        final data = r.data;
        if (data is List) {
          result.addAll(records(data, RecruiterInterview.fromJson));
          return List.unmodifiable(result);
        }
        final parsed = PaginatedResponse<RecruiterInterview>.fromJson(
          object(data),
          RecruiterInterview.fromJson,
        );
        result.addAll(parsed.results);
        if (!parsed.hasNext) return List.unmodifiable(result);
      }
      throw StateError('Interview pagination did not finish.');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<RecruitmentReview> review(
    String applicationId, {
    String? interviewId,
    CancelToken? cancelToken,
  }) async {
    final app = await request(
      '/applications/$applicationId/',
      cancelToken: cancelToken,
    );
    final attempts = (await interviews(
      cancelToken: cancelToken,
    )).where((i) => i.applicationId == applicationId).toList(growable: false);
    final interview = interviewId == null
        ? attempts.firstOrNull
        : attempts.where((i) => i.id == interviewId).firstOrNull;
    if (interviewId != null && interview == null) {
      throw StateError('Interview does not belong to this application.');
    }
    final values = await Future.wait([
      request(
        '/applications/$applicationId/scoring/',
        cancelToken: cancelToken,
      ),
      request(
        '/applications/$applicationId/workflow-history/',
        cancelToken: cancelToken,
      ),
      if (interview != null) ...[
        request(
          '/interviews/${interview.id}/transcript-revisions/',
          cancelToken: cancelToken,
        ),
        request(
          '/interviews/${interview.id}/evaluations/',
          cancelToken: cancelToken,
        ),
        request(
          '/interviews/${interview.id}/feedback-review/',
          cancelToken: cancelToken,
        ),
      ],
    ]);
    return RecruitmentReview(
      application: Application.fromJson(app),
      decision: app['decision'] == null
          ? null
          : RecruiterDecision.fromJson(object(app['decision'])),
      attempts: List.unmodifiable(attempts),
      interview: interview,
      scores: ScoreHistory.fromJson(values[0]),
      actions: RevisionHistory<WorkflowAction>.fromJson(
        values[1],
        'actions',
        WorkflowAction.fromJson,
      ).revisions,
      transcripts: interview == null
          ? null
          : TranscriptHistory.fromJson(values[2]),
      evaluations: interview == null
          ? null
          : EvaluationHistory.fromJson(values[3]),
      feedback: interview == null
          ? const []
          : RevisionHistory<FeedbackReviewRevision>.fromJson(
              values[4],
              'reports',
              FeedbackReviewRevision.fromJson,
            ).revisions,
    );
  }

  static String reason(String value) {
    final text = value.trim();
    if (text.isEmpty || text.length > 2000) {
      throw ArgumentError('A reason of 1–2000 characters is required.');
    }
    return text;
  }

  Future<Json> selectTranscript(
    RecruitmentReview r,
    String transcriptId,
    String explanation,
  ) {
    final version = r.transcripts?.version;
    if (r.interview == null ||
        version == null ||
        !r.transcripts!.revisions.any((t) => t.id == transcriptId)) {
      throw StateError('Review the transcript selection first.');
    }
    return request(
      '/interviews/${r.interview!.id}/select-transcript/',
      data: {
        'expected_version': r.application.version,
        'expected_selection_version': version.value,
        'transcript_id': transcriptId,
        'reason': reason(explanation),
      },
    );
  }

  Future<Json> rerun(RecruitmentReview r, String explanation) {
    final evaluation = r.latestEvaluation;
    if (r.interview == null || evaluation?.terminal != true) {
      throw StateError('Review the latest terminal evaluation first.');
    }
    return request(
      '/interviews/${r.interview!.id}/rerun-evaluation/',
      data: {
        'expected_version': r.application.version,
        'expected_revision': evaluation!.revision.value,
        'reason': reason(explanation),
      },
    );
  }

  Future<Json> decide(
    RecruitmentReview r,
    String outcome,
    String explanation, {
    String? overrideReason,
  }) {
    if (!const {'HIRE', 'REJECT'}.contains(outcome)) {
      throw ArgumentError('Unknown outcome.');
    }
    if (overrideReason == null && !r.normalDecisionReady) {
      throw StateError('Published, complete usable evidence is required.');
    }
    return request(
      '/applications/${r.application.id}/decision/',
      data: {
        'expected_version': r.application.version,
        'outcome': outcome,
        'reason': reason(explanation),
        if (overrideReason != null) ...{
          'override': true,
          'override_reason': reason(overrideReason),
        },
      },
    );
  }

  Future<Json> reverse(RecruitmentReview r, String explanation) => request(
    '/applications/${r.application.id}/reverse-decision/',
    data: {
      'expected_version': r.application.version,
      'reason': reason(explanation),
    },
  );
  Future<RecruiterInterview> recover(
    RecruitmentReview r,
    DateTime scheduledAt,
    String explanation, {
    required bool reopen,
  }) async {
    if (r.interview == null ||
        !r.latestAttempt ||
        !scheduledAt.isAfter(DateTime.now())) {
      throw StateError('Choose the latest attempt and a future time.');
    }
    final data = await request(
      '/interviews/${r.interview!.id}/${reopen ? 'reopen' : 'reschedule'}/',
      data: {
        'expected_version': r.application.version,
        'scheduled_at': ApiValue.timestamp(scheduledAt),
        'reason': reason(explanation),
      },
    );
    final next = RecruiterInterview.fromJson(data);
    if (next.applicationId != r.application.id ||
        (reopen ? next.id == r.interview!.id : next.id != r.interview!.id)) {
      throw const FormatException(
        'Recovery returned an unexpected interview identity.',
      );
    }
    return next;
  }

  Future<PaginatedResponse<RankingRow>> ranking(
    String jobId,
    int page, {
    CancelToken? cancelToken,
  }) async => PaginatedResponse.fromJson(
    await request(
      '/jobs/$jobId/ranking/',
      query: {'page': page},
      cancelToken: cancelToken,
    ),
    RankingRow.fromJson,
  );
}
