/// Application status enum matching Django [Application.Status].
enum ApplicationStatus {
  applied('APPLIED'),
  screened('SCREENED'),
  interviewed('INTERVIEWED'),
  decision('DECISION');

  final String value;
  const ApplicationStatus(this.value);

  static ApplicationStatus fromString(String val) {
    return ApplicationStatus.values.firstWhere(
      (e) => e.value == val.toUpperCase(),
      orElse: () => ApplicationStatus.applied,
    );
  }

  /// Returns the single next valid status in the forward-only lifecycle.
  ///
  /// Returns null if already in terminal state ('DECISION').
  ApplicationStatus? get nextStatus => switch (this) {
        ApplicationStatus.applied => ApplicationStatus.screened,
        ApplicationStatus.screened => ApplicationStatus.interviewed,
        ApplicationStatus.interviewed => ApplicationStatus.decision,
        ApplicationStatus.decision => null,
      };
}

/// Job Application model — mirrors Django's [ApplicationDetailSerializer]
/// and [ApplicationListSerializer].
class Application {
  final String id;
  final String candidate;
  final String candidateEmail;
  final String job;
  final String jobTitle;
  final String? resumeId;
  final ApplicationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Application({
    required this.id,
    required this.candidate,
    required this.candidateEmail,
    required this.job,
    required this.jobTitle,
    this.resumeId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      id: json['id'] as String,
      candidate: json['candidate'] as String? ?? '',
      candidateEmail: json['candidate_email'] as String? ?? '',
      job: json['job'] as String? ?? '',
      jobTitle: json['job_title'] as String? ?? '',
      resumeId: json['resume_id'] as String?,
      status: ApplicationStatus.fromString(json['status'] as String? ?? 'APPLIED'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() => 'Application($jobTitle, candidate=$candidateEmail, status=${status.value})';
}
