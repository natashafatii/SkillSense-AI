import 'api_contract.dart';

class QuestionReadiness {
  final String state;
  final int approvedQuestionCount;
  final bool canStart;
  const QuestionReadiness({
    this.state = 'UNKNOWN',
    this.approvedQuestionCount = 0,
    this.canStart = false,
  });
  factory QuestionReadiness.fromJson(Map<String, dynamic> json) =>
      QuestionReadiness(
        state: json['state']?.toString() ?? 'UNKNOWN',
        approvedQuestionCount: json['approved_question_count'] == null
            ? 0
            : ApiValue.integer(json['approved_question_count']),
        canStart: json['can_start'] == true,
      );
}

/// Shared public interview identity and lifecycle. It never retains questions.
class Interview {
  final String id, applicationId, status, workflowState;
  final DateTime? scheduledAt, completedAt;
  final QuestionReadiness questionReadiness;
  const Interview({
    required this.id,
    required this.applicationId,
    this.scheduledAt,
    this.status = 'SCHEDULED',
    this.workflowState = 'UNKNOWN',
    this.completedAt,
    this.questionReadiness = const QuestionReadiness(),
  });
  String get questionPreparationMode => '';
  String get questionFallbackReason => '';
  bool canJoinAt(DateTime now) =>
      questionReadiness.state == 'READY' &&
      questionReadiness.approvedQuestionCount > 0 &&
      questionReadiness.canStart &&
      const {'SCHEDULED', 'IN_PROGRESS'}.contains(workflowState) &&
      (status == 'LIVE' ||
          (status == 'SCHEDULED' &&
              scheduledAt != null &&
              !now.isBefore(
                scheduledAt!.subtract(const Duration(minutes: 15)),
              )));
  factory Interview.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Interview response is missing an ID.');
    }
    return Interview(
      id: id,
      applicationId: (json['application'] ?? json['application_id'] ?? '')
          .toString(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      workflowState: json['workflow_state']?.toString() ?? 'UNKNOWN',
      scheduledAt: ApiValue.instant(
        json['scheduled_at'] ?? json['scheduled_time'],
      ),
      completedAt: ApiValue.instant(json['completed_at']),
      questionReadiness: json['question_readiness'] is Map
          ? QuestionReadiness.fromJson(
              Map<String, dynamic>.from(json['question_readiness'] as Map),
            )
          : const QuestionReadiness(),
    );
  }
  factory Interview.forRole(Map<String, dynamic> json, String role) =>
      role == 'RECRUITER'
      ? RecruiterInterview.fromJson(json)
      : CandidateInterview.fromJson(json);
  Interview.copy(Interview value)
    : id = value.id,
      applicationId = value.applicationId,
      status = value.status,
      workflowState = value.workflowState,
      scheduledAt = value.scheduledAt,
      completedAt = value.completedAt,
      questionReadiness = value.questionReadiness;
}

/// Selected by the verified role, never by the presence of private JSON keys.
class CandidateInterview extends Interview {
  CandidateInterview.fromJson(Map<String, dynamic> json)
    : super.copy(Interview.fromJson(json));
}

class RecruiterInterview extends Interview {
  final List<InterviewQuestion> questions;
  final String completionOutcome, evaluationStatus;
  @override
  final String questionPreparationMode;
  @override
  final String questionFallbackReason;
  RecruiterInterview.fromJson(Map<String, dynamic> json)
    : questions = List.unmodifiable(
        (json['questions'] as List? ?? []).map(
          (q) =>
              InterviewQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
        ),
      ),
      completionOutcome = json['completion_outcome']?.toString() ?? 'UNKNOWN',
      evaluationStatus = json['evaluation_status']?.toString() ?? 'UNKNOWN',
      questionPreparationMode =
          json['question_preparation_mode']?.toString() ?? 'LEGACY_UNVERIFIED',
      questionFallbackReason =
          json['question_fallback_reason']?.toString() ?? '',
      super.copy(Interview.fromJson(json));
}

class InterviewQuestion {
  final String id;
  final String text;
  final bool isApproved;
  final String source;

  const InterviewQuestion({
    required this.id,
    required this.text,
    required this.isApproved,
    this.source = 'LEGACY_UNVERIFIED',
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final text =
        (json['text'] ?? json['question_text'] ?? json['question'] ?? '')
            .toString();
    if (id.isEmpty || text.isEmpty) {
      throw const FormatException(
        'Interview question is missing an ID or text.',
      );
    }
    return InterviewQuestion(
      id: id,
      text: text,
      isApproved: json['is_approved'] == true || json['approved'] == true,
      source: json['source']?.toString() ?? 'LEGACY_UNVERIFIED',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'is_approved': isApproved,
  };
}
