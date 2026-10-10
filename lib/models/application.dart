/// Application status enum matching Django [Application.Status].
enum ApplicationStatus {
  applied('APPLIED'),
  screened('SHORTLISTED'),
  underReview('UNDER_REVIEW'),
  rejected('REJECTED'),
  interviewed('INTERVIEWED'),
  decision('DECISION');

  final String value;
  const ApplicationStatus(this.value);

  static ApplicationStatus fromString(String val) {
    return switch (val.toUpperCase()) {
      'PENDING' || 'APPLIED' => ApplicationStatus.applied,
      'SCREENED' || 'SHORTLISTED' => ApplicationStatus.screened,
      'SCREENING' || 'UNDER_REVIEW' => ApplicationStatus.underReview,
      'REJECTED' => ApplicationStatus.rejected,
      'INTERVIEWED' => ApplicationStatus.interviewed,
      'DECIDED' || 'DECISION' => ApplicationStatus.decision,
      _ => throw FormatException('Unknown application status: $val'),
    };
  }

  /// Returns the single next valid status in the forward-only lifecycle.
  ///
  /// Returns null if already in terminal state ('DECISION').
  ApplicationStatus? get nextStatus => switch (this) {
    ApplicationStatus.applied => ApplicationStatus.screened,
    ApplicationStatus.screened => ApplicationStatus.interviewed,
    ApplicationStatus.interviewed => ApplicationStatus.decision,
    ApplicationStatus.decision || ApplicationStatus.rejected => null,
    ApplicationStatus.underReview => ApplicationStatus.screened,
  };
}

/// Job Application model — mirrors Django's [ApplicationDetailSerializer]
/// and [ApplicationListSerializer].
class Application {
  final int version;
  final Map<String, dynamic>? assessment;
  final List<String> allowedActions;
  final bool eligibleForInterview;
  final String id;
  final String candidate;
  final String candidateEmail;
  final String job;
  final String jobTitle;
  final String? resumeId;
  final ApplicationStatus status;
  final String? rawStatus;
  final String? candidateName;
  final double? resumeScore;
  final double? technicalScore;
  final double? behavioralScore;
  final double? communicationScore;
  final String? outcome;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Application({
    this.version = 1,
    this.assessment,
    this.allowedActions = const [],
    this.eligibleForInterview = false,
    required this.id,
    required this.candidate,
    required this.candidateEmail,
    required this.job,
    required this.jobTitle,
    this.resumeId,
    required this.status,
    this.rawStatus,
    this.candidateName,
    this.resumeScore,
    this.technicalScore,
    this.behavioralScore,
    this.communicationScore,
    this.outcome,
    required this.createdAt,
    this.updatedAt,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String;
    final scores = json['scores'] is Map ? json['scores'] as Map : const {};
    double? numeric(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value');
    return Application(
      version: (json['version'] as num?)?.toInt() ?? 1,
      assessment: json['assessment'] is Map
          ? Map<String, dynamic>.from(json['assessment'] as Map)
          : null,
      allowedActions:
          (json['allowed_actions'] as List?)?.cast<String>() ?? const [],
      eligibleForInterview: json['eligible_for_interview'] == true,
      id: json['id'] as String,
      candidate: json['candidate'] as String? ?? '',
      candidateEmail: json['candidate_email'] as String? ?? '',
      job: json['job'] as String? ?? '',
      jobTitle: json['job_title'] as String? ?? '',
      resumeId: json['resume_id'] as String?,
      status: ApplicationStatus.fromString(rawStatus),
      rawStatus: rawStatus,
      candidateName: (json['candidate_name'] ?? json['name']) as String?,
      resumeScore: numeric(
        json['resume_score'] ?? json['match_score'] ?? json['score'],
      ),
      technicalScore: numeric(json['technical_score'] ?? scores['technical']),
      behavioralScore: numeric(
        json['behavioral_score'] ?? scores['behavioral'],
      ),
      communicationScore: numeric(
        json['communication_score'] ?? scores['communication'],
      ),
      outcome: json['outcome'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'Application($jobTitle, candidate=$candidateEmail, status=${status.value})';
}
