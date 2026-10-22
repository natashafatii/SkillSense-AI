import 'api_contract.dart';

typedef Json = Map<String, dynamic>;
Json object(Object? value) => Map<String, dynamic>.from(value as Map);
List<T> records<T>(Object? value, T Function(Json) parse) => List.unmodifiable(
  (value as List? ?? const []).map((row) => parse(object(row))),
);
List<String> strings(Object? value) => List.unmodifiable(
  (value as List? ?? const []).map((value) => value.toString()),
);
double? bounded(Object? value, double maximum) {
  final number = ApiValue.number(value);
  if (number != null && (number < 0 || number > maximum)) {
    throw const FormatException('Evidence number outside its contract range.');
  }
  return number;
}

class TranscriptTurn {
  final String id, role, text;
  final double? start, end;
  TranscriptTurn.fromJson(Json j)
    : id = j['id'].toString(),
      role = j['role'].toString(),
      text = j['text']?.toString() ?? '',
      start = ApiValue.number(j['start_seconds']),
      end = ApiValue.number(j['end_seconds']);
}

class TranscriptRevision {
  final String id, source, hash, text, callId;
  final int number;
  final DateTime? createdAt;
  final List<TranscriptTurn> turns;
  TranscriptRevision.fromJson(Json j)
    : id = j['id'].toString(),
      callId = j['call_id']?.toString() ?? '',
      source = j['source']?.toString() ?? 'UNKNOWN',
      hash = j['content_hash']?.toString() ?? '',
      text = j['text']?.toString() ?? '',
      number = ApiValue.integer(j['number']),
      createdAt = ApiValue.instant(j['created_at']),
      turns = records(j['turns'], TranscriptTurn.fromJson);
}

class TranscriptHistory {
  final String? selected;
  final TranscriptSelectionVersion? version;
  final bool pinned;
  final List<TranscriptRevision> revisions;
  TranscriptHistory.fromJson(Json j)
    : selected = j['selected_revision']?.toString(),
      version = j['selection_version'] == null
          ? null
          : TranscriptSelectionVersion(
              ApiValue.integer(j['selection_version']),
            ),
      pinned = j['selection_pinned'] == true,
      revisions = RevisionHistory<TranscriptRevision>.fromJson(
        j,
        'revisions',
        TranscriptRevision.fromJson,
      ).revisions;
}

class EvidenceQuote {
  final String turnId, quote;
  EvidenceQuote.fromJson(Json j)
    : turnId = j['turn_id'].toString(),
      quote = j['quote']?.toString() ?? '';
}

class EvidenceSpan {
  final String turnId;
  final int start, end;
  final double? startSeconds, endSeconds;
  EvidenceSpan.fromJson(Json j)
    : turnId = j['turn_id'].toString(),
      start = ApiValue.integer(j['start_offset']),
      end = ApiValue.integer(j['end_offset']),
      startSeconds = ApiValue.number(j['start_seconds']),
      endSeconds = ApiValue.number(j['end_seconds']);
  String? textIn(TranscriptTurn turn) {
    final points = turn.text.runes.toList();
    if (turn.id != turnId || start < 0 || end < start || end > points.length) {
      return null;
    }
    return String.fromCharCodes(points.sublist(start, end));
  }
}

class ExtractedAnswer {
  final String questionId, state, method;
  final String? askedTurnId;
  final double? confidence;
  final List<String> answerTurnIds, followUpTurnIds;
  final List<EvidenceSpan> spans;
  ExtractedAnswer.fromJson(Json j)
    : questionId = j['question_id'].toString(),
      state = j['state']?.toString() ?? 'UNKNOWN',
      method = j['method']?.toString() ?? 'UNKNOWN',
      askedTurnId = j['asked_turn_id']?.toString(),
      confidence = bounded(j['confidence'], 1),
      answerTurnIds = strings(j['answer_turn_ids']),
      followUpTurnIds = strings(j['follow_up_turn_ids']),
      spans = records(j['spans'], EvidenceSpan.fromJson);
}

class AnswerExtraction {
  final List<ExtractedAnswer> questions;
  final List<String> unmatchedTurnIds;
  AnswerExtraction.fromJson(Json j)
    : questions = records(j['questions'], ExtractedAnswer.fromJson),
      unmatchedTurnIds = strings(j['unmatched_turn_ids']);
}

class AnswerResult {
  final String questionId, status, rationale;
  final Map<String, double?> criteria;
  final List<String> strengths, gaps;
  final List<EvidenceQuote> evidence;
  final double? uncertainty;
  AnswerResult.fromJson(Json j)
    : questionId = j['question_id'].toString(),
      status = j['status']?.toString() ?? 'UNKNOWN',
      rationale = j['rationale']?.toString() ?? '',
      criteria = Map.unmodifiable(
        (j['criteria'] as Map? ?? {}).map(
          (key, value) => MapEntry('$key', bounded(value, 1)),
        ),
      ),
      strengths = strings(j['strengths']),
      gaps = strings(j['gaps']),
      evidence = records(j['evidence'], EvidenceQuote.fromJson),
      uncertainty = bounded(j['uncertainty'], 1);
}

class EvaluationRevision {
  final String id, status, transcriptHash, contract, model, error, contextHash;
  final String? supersedes;
  final EvidenceRevision revision;
  final int? transcriptNumber, runNumber;
  final int attempts;
  final double? score, coverage;
  final DateTime? publishedAt, nextAttemptAt;
  final bool feedbackReleased;
  final List<AnswerResult> answers;
  final AnswerExtraction? extraction;
  EvaluationRevision.fromJson(Json j)
    : id = j['id'].toString(),
      status = j['status']?.toString() ?? 'UNKNOWN',
      revision = EvidenceRevision(ApiValue.integer(j['revision'])),
      transcriptNumber = j['transcript_revision'] == null
          ? null
          : ApiValue.integer(j['transcript_revision']),
      transcriptHash = j['transcript_hash']?.toString() ?? '',
      contextHash = j['context_hash']?.toString() ?? '',
      supersedes = j['supersedes']?.toString(),
      contract = j['contract_version']?.toString() ?? 'UNKNOWN',
      model = j['model_name']?.toString() ?? '',
      error = j['error_code']?.toString() ?? '',
      score = bounded(j['score'], 100),
      coverage = bounded(j['coverage'], 1),
      publishedAt = ApiValue.instant(j['published_at']),
      nextAttemptAt = ApiValue.instant(j['next_attempt_at']),
      attempts = j['attempts'] == null ? 0 : ApiValue.integer(j['attempts']),
      runNumber = j['run_number'] == null
          ? null
          : ApiValue.integer(j['run_number']),
      feedbackReleased = j['feedback_released'] == true,
      answers = records(j['answers'], AnswerResult.fromJson),
      extraction = j['extraction'] == null
          ? null
          : AnswerExtraction.fromJson(object(j['extraction']));
  bool get pending => const {'QUEUED', 'PROCESSING'}.contains(status);
  bool get terminal =>
      const {'READY', 'FAILED', 'UNAVAILABLE'}.contains(status);
  TranscriptRevision? frozenTranscript(TranscriptHistory history) {
    for (final t in history.revisions) {
      if (t.number == transcriptNumber &&
          t.hash == transcriptHash &&
          transcriptHash.isNotEmpty) {
        return t;
      }
    }
    return null;
  }
}

class EvaluationHistory {
  final String transcriptState, reason, selectedSource;
  final DateTime? deadline;
  final List<EvaluationRevision> revisions;
  EvaluationHistory.fromJson(Json j)
    : transcriptState =
          (j['transcript'] as Map?)?['state']?.toString() ?? 'UNKNOWN',
      reason = (j['transcript'] as Map?)?['reason']?.toString() ?? '',
      selectedSource =
          (j['transcript'] as Map?)?['selected_source']?.toString() ?? '',
      deadline = ApiValue.instant((j['transcript'] as Map?)?['deadline']),
      revisions = RevisionHistory<EvaluationRevision>.fromJson(
        j,
        'evaluations',
        EvaluationRevision.fromJson,
      ).revisions;
}

class ServerScore {
  final String status, error, explanation;
  final String? id, rubric;
  final int? revision, rubricVersion;
  final String? policyVersion;
  final double? match, interview, combined, coverage, answerCoverage;
  final Map<String, double?> weights, breakdown;
  final String? assessmentId, evaluationId;
  final int? assessmentRevision, evaluationRevision;
  final DateTime? completedAt;
  ServerScore.fromJson(Json j)
    : status = j['status']?.toString() ?? 'UNKNOWN',
      id = j['score_revision']?.toString(),
      revision = j['revision'] == null ? null : ApiValue.integer(j['revision']),
      rubric = j['rubric']?.toString(),
      rubricVersion = j['rubric_version'] == null
          ? null
          : ApiValue.integer(j['rubric_version']),
      policyVersion = j['policy_version']?.toString(),
      error = j['error_code']?.toString() ?? '',
      explanation = j['explanation']?.toString() ?? '',
      match = bounded(j['screening_match_percentage'], 100),
      interview = bounded(j['interview_performance_percentage'], 100),
      combined = bounded(
        j.containsKey('combined_recommendation_percentage')
            ? j['combined_recommendation_percentage']
            : j['final_score'],
        100,
      ),
      coverage = bounded(j['coverage'], 1),
      answerCoverage = bounded(j['answer_coverage'], 1),
      weights = Map.unmodifiable(
        (j['weights'] as Map? ?? {}).map(
          (key, value) => MapEntry('$key', bounded(value, 1)),
        ),
      ),
      breakdown = Map.unmodifiable(
        (j['breakdown'] as Map? ?? {}).map(
          (key, value) => MapEntry('$key', bounded(value, 100)),
        ),
      ),
      assessmentId = (j['source_revisions'] as Map?)?['assessment']?.toString(),
      evaluationId = (j['source_revisions'] as Map?)?['evaluation']?.toString(),
      assessmentRevision = _optionalInt(
        (j['source_revisions'] as Map?)?['assessment_revision'],
      ),
      evaluationRevision = _optionalInt(
        (j['source_revisions'] as Map?)?['evaluation_revision'],
      ),
      completedAt = ApiValue.instant(j['completed_at']);
  double? get publishedCombined => status == 'COMPLETE' ? combined : null;
  bool get pending =>
      const {'PENDING', 'QUEUED', 'PROCESSING'}.contains(status);
}

int? _optionalInt(Object? v) => v == null ? null : ApiValue.integer(v);

class ScoreRevision {
  final String id, status, error;
  final int number, attempts;
  final double? score, match, interview, coverage;
  final Map<String, dynamic> inputs;
  final DateTime? createdAt, completedAt;
  ScoreRevision.fromJson(Json j)
    : id = j['id'].toString(),
      number = ApiValue.integer(j['number']),
      status = j['status']?.toString() ?? 'UNKNOWN',
      error = j['error_code']?.toString() ?? '',
      attempts = j['attempts'] == null ? 0 : ApiValue.integer(j['attempts']),
      score = bounded(j['final_score'], 100),
      match = bounded(j['screening_match_percentage'], 100),
      interview = bounded(j['interview_performance_percentage'], 100),
      coverage = bounded(j['coverage'], 1),
      inputs = Map.unmodifiable(object(j['inputs'] ?? {})),
      createdAt = ApiValue.instant(j['created_at']),
      completedAt = ApiValue.instant(j['completed_at']);
}

class ScoreHistory {
  final ServerScore? current;
  final List<ScoreRevision> history;
  ScoreHistory.fromJson(Json j)
    : current = j['current'] == null
          ? null
          : ServerScore.fromJson(object(j['current'])),
      history = RevisionHistory<ScoreRevision>.fromJson(
        j,
        'history',
        ScoreRevision.fromJson,
      ).revisions;
}

class RecruiterDecision {
  final String? outcome, actor, reason, evaluation, overrideReason;
  final bool override, legacy;
  final int? applicationVersion;
  final DateTime? createdAt;
  RecruiterDecision.fromJson(Json j)
    : outcome = j['outcome']?.toString(),
      actor = j['actor']?.toString(),
      reason = j['reason']?.toString(),
      evaluation = j['evaluation']?.toString(),
      overrideReason = j['override_reason']?.toString(),
      override = j['override'] == true,
      legacy = j['legacy_unrecorded'] == true,
      applicationVersion = _optionalInt(j['application_version']),
      createdAt = ApiValue.instant(j['created_at']);
}

class WorkflowAction {
  final String id, action, reason;
  final String? interviewId, actorId;
  final int? expectedVersion;
  final Map<String, dynamic> details;
  final DateTime? createdAt;
  WorkflowAction.fromJson(Json j)
    : id = j['id'].toString(),
      action = j['action']?.toString() ?? 'UNKNOWN',
      reason = j['reason']?.toString() ?? '',
      interviewId = j['interview_id']?.toString(),
      actorId = j['actor_id']?.toString(),
      expectedVersion = _optionalInt(j['expected_version']),
      details = Map.unmodifiable(object(j['details'] ?? {})),
      createdAt = ApiValue.instant(j['created_at']);
}

class FeedbackReviewRevision {
  final String id, status, contract, hash;
  final String? evaluation, error;
  final FeedbackRevision revision;
  final FeedbackEditVersion editVersion;
  final DateTime? preparedAt, releasedAt, retractedAt;
  FeedbackReviewRevision.fromJson(Json j)
    : id = j['id'].toString(),
      revision = FeedbackRevision(ApiValue.integer(j['revision'])),
      editVersion = FeedbackEditVersion(ApiValue.integer(j['edit_version'])),
      status = j['status']?.toString() ?? 'UNKNOWN',
      contract = j['contract_version']?.toString() ?? '',
      hash = j['content_hash']?.toString() ?? '',
      evaluation = j['evaluation']?.toString(),
      error = j['error_code']?.toString(),
      preparedAt = ApiValue.instant(j['prepared_at']),
      releasedAt = ApiValue.instant(j['released_at']),
      retractedAt = ApiValue.instant(j['retracted_at']);
}

class RankingRow {
  final String applicationId, candidateId, name, email, status;
  final double? finalScore;
  final int? rubricVersion;
  RankingRow.fromJson(Json j)
    : applicationId = j['id'].toString(),
      candidateId = j['candidate']?.toString() ?? '',
      name = j['candidate_name']?.toString() ?? '',
      email = j['candidate_email']?.toString() ?? '',
      status = j['score_status']?.toString() ?? 'UNKNOWN',
      finalScore = bounded(j['final_score'], 100),
      rubricVersion = _optionalInt(j['rubric_version']);
}
