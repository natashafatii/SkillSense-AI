import 'api_contract.dart';
import 'screening_assessment.dart';

/// Application status enum matching Django [Application.Status].
enum ApplicationStatus {
  applied('APPLIED'),
  screened('SHORTLISTED'),
  underReview('UNDER_REVIEW'),
  rejected('REJECTED'),
  scheduled('SCHEDULED'),
  inProgress('IN_PROGRESS'),
  interviewFailed('INTERVIEW_FAILED'),
  interviewed('INTERVIEWED'),
  decision('DECISION'),
  unknown('UNKNOWN');

  final String value;
  const ApplicationStatus(this.value);

  static ApplicationStatus fromString(String val) {
    return switch (val.toUpperCase()) {
      'PENDING' || 'APPLIED' => ApplicationStatus.applied,
      'SCREENED' || 'SHORTLISTED' => ApplicationStatus.screened,
      'SCREENING' || 'UNDER_REVIEW' => ApplicationStatus.underReview,
      'REJECTED' => ApplicationStatus.rejected,
      'SCHEDULED' => ApplicationStatus.scheduled,
      'IN_PROGRESS' => ApplicationStatus.inProgress,
      'INTERVIEW_FAILED' => ApplicationStatus.interviewFailed,
      'INTERVIEWED' => ApplicationStatus.interviewed,
      'DECIDED' || 'DECISION' => ApplicationStatus.decision,
      _ => ApplicationStatus.unknown,
    };
  }

  /// Lifecycle stages are applied by server commands, never inferred locally.
  ApplicationStatus? get nextStatus => null;
}

/// Job Application model — mirrors Django's [ApplicationDetailSerializer]
/// and [ApplicationListSerializer].
class Application {
  final int version;
  final List<Map<String, dynamic>> history;
  ScreeningAssessment? get screening =>
      assessment == null ? null : ScreeningAssessment.fromJson(assessment!);
  bool get canPrepareQuestions =>
      version > 0 &&
      eligibleForInterview &&
      status == ApplicationStatus.screened &&
      screening?.status == 'SUCCEEDED';
  ApplicationVersion get applicationVersion => ApplicationVersion(version);
  final Map<String, dynamic>? assessment;
  final List<String> allowedActions;
  final bool eligibleForInterview;
  final String id;
  final String candidate;
  final String candidateEmail;
  final String job;
  final String jobTitle;
  final String jobCompany;
  final String? resumeId;
  final String? coverNote;
  final ApplicationStatus status;
  final String? rawStatus;
  final String? candidateName;
  final String? candidateProfileImageUrl;
  final double? resumeScore;
  final double? technicalScore;
  final double? behavioralScore;
  final double? communicationScore;
  final String? outcome;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Application({
    this.version = 1,
    this.history = const [],
    this.assessment,
    this.allowedActions = const [],
    this.eligibleForInterview = false,
    required this.id,
    required this.candidate,
    required this.candidateEmail,
    required this.job,
    required this.jobTitle,
    this.jobCompany = '',
    this.resumeId,
    this.coverNote,
    required this.status,
    this.rawStatus,
    this.candidateName,
    this.candidateProfileImageUrl,
    this.resumeScore,
    this.technicalScore,
    this.behavioralScore,
    this.communicationScore,
    this.outcome,
    required this.createdAt,
    this.updatedAt,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? 'UNKNOWN';
    final scores = json['scores'] is Map ? json['scores'] as Map : const {};
    double? numeric(dynamic value) => ApiValue.number(value);
    return Application(
      history: (json['history'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      version: json['version'] == null ? 0 : ApiValue.integer(json['version']),
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
      jobCompany: json['job_company'] as String? ?? '',
      resumeId: json['resume_id'] as String?,
      coverNote: json['cover_note'] as String?,
      status: ApplicationStatus.fromString(rawStatus),
      rawStatus: rawStatus,
      candidateName: (json['candidate_name'] ?? json['name']) as String?,
      candidateProfileImageUrl:
          (json['candidate_profile_image_url'] ?? json['profile_image_url'])
              as String?,
      resumeScore: numeric(
        json.containsKey('match_score')
            ? json['match_score']
            : json['resume_score'],
      ),
      technicalScore: numeric(json['technical_score'] ?? scores['technical']),
      behavioralScore: numeric(
        json['behavioral_score'] ?? scores['behavioral'],
      ),
      communicationScore: numeric(
        json['communication_score'] ?? scores['communication'],
      ),
      outcome: json['outcome'] as String?,
      createdAt: ApiValue.instant(json['created_at'])!,
      updatedAt: json['updated_at'] != null
          ? ApiValue.instant(json['updated_at'])
          : null,
    );
  }

  Application withShortlistResult(Map<String, dynamic> result) {
    final nextStatus =
        result['status']?.toString() ?? rawStatus ?? status.value;
    return Application(
      version: (result['version'] as num?)?.toInt() ?? version,
      assessment: assessment,
      history: history,
      allowedActions:
          (result['allowed_actions'] as List?)?.cast<String>() ??
          allowedActions,
      eligibleForInterview: result['eligible_for_interview'] == true,
      id: id,
      candidate: candidate,
      candidateEmail: candidateEmail,
      job: job,
      jobTitle: jobTitle,
      jobCompany: jobCompany,
      resumeId: resumeId,
      coverNote: coverNote,
      status: ApplicationStatus.fromString(nextStatus),
      rawStatus: nextStatus,
      candidateName: candidateName,
      candidateProfileImageUrl: candidateProfileImageUrl,
      resumeScore: resumeScore,
      technicalScore: technicalScore,
      behavioralScore: behavioralScore,
      communicationScore: communicationScore,
      outcome: outcome,
      createdAt: createdAt,
      updatedAt: result['updated_at'] is String
          ? ApiValue.instant(result['updated_at']) ?? updatedAt
          : updatedAt,
    );
  }

  @override
  String toString() =>
      'Application($jobTitle, candidate=$candidateEmail, status=${status.value})';
}
