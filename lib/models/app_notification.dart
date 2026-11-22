enum NotificationEvent {
  applicationReceived('application_received'),
  applicationStatusChanged('application_status_changed'),
  interviewScheduled('interview_scheduled'),
  questionReviewReady('question_review_ready'),
  evaluationReady('evaluation_ready'),
  evaluationFailed('evaluation_failed'),
  scoreReady('score_ready'),
  feedbackReleased('feedback_released'),
  feedbackRetracted('feedback_retracted'),
  unknown('');

  const NotificationEvent(this.wire);
  final String wire;
  static NotificationEvent parse(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => unknown);
}

extension type ResourceUuid._(String value) {
  static ResourceUuid? parse(Object? value) =>
      value is String &&
          RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(value)
      ? ResourceUuid._(value.toLowerCase())
      : null;
}

class NotificationLinks {
  final ResourceUuid? application,
      interview,
      questionSet,
      evaluation,
      scoreRevision,
      feedbackReport;
  const NotificationLinks.empty()
    : application = null,
      interview = null,
      questionSet = null,
      evaluation = null,
      scoreRevision = null,
      feedbackReport = null;
  NotificationLinks.fromJson(Object? value)
    : application = ResourceUuid.parse(
        value is Map ? value['application_id'] : null,
      ),
      interview = ResourceUuid.parse(
        value is Map ? value['interview_id'] : null,
      ),
      questionSet = ResourceUuid.parse(
        value is Map ? value['question_set_id'] : null,
      ),
      evaluation = ResourceUuid.parse(
        value is Map ? value['evaluation_id'] : null,
      ),
      scoreRevision = ResourceUuid.parse(
        value is Map ? value['score_revision_id'] : null,
      ),
      feedbackReport = ResourceUuid.parse(
        value is Map ? value['feedback_report_id'] : null,
      );
}

class NotificationDetails {
  const NotificationDetails({
    this.jobTitle,
    this.companyName,
    this.candidateName,
    this.currentApplicationStatus,
    this.scheduledAt,
    this.deadlineAt,
  });

  final String? jobTitle, companyName, candidateName, currentApplicationStatus;
  final DateTime? scheduledAt, deadlineAt;

  factory NotificationDetails.fromJson(Object? value) {
    if (value is! Map) return const NotificationDetails();
    String? readText(String key) {
      final field = value[key];
      if (field is! String || field.trim().isEmpty) return null;
      return field.trim();
    }

    final scheduledAt = readText('scheduled_at');
    final deadlineAt = readText('deadline_at');
    return NotificationDetails(
      jobTitle: readText('job_title'),
      companyName: readText('company_name'),
      candidateName: readText('candidate_name'),
      currentApplicationStatus: readText('current_application_status'),
      scheduledAt: scheduledAt == null ? null : DateTime.tryParse(scheduledAt),
      deadlineAt: deadlineAt == null ? null : DateTime.tryParse(deadlineAt),
    );
  }
}

class AppNotification {
  final String id;
  final String type;
  final NotificationLinks links;
  final NotificationDetails details;
  NotificationEvent get event => NotificationEvent.parse(type);
  String get displayType => switch (event) {
    NotificationEvent.applicationReceived => 'Application received',
    NotificationEvent.applicationStatusChanged => 'Application update',
    NotificationEvent.interviewScheduled => 'Interview scheduled',
    NotificationEvent.questionReviewReady => 'Interview questions ready',
    NotificationEvent.evaluationReady => 'Interview evaluation ready',
    NotificationEvent.evaluationFailed => 'Interview evaluation unavailable',
    NotificationEvent.scoreReady => 'Combined score ready',
    NotificationEvent.feedbackReleased => 'Interview feedback released',
    NotificationEvent.feedbackRetracted => 'Interview feedback withdrawn',
    NotificationEvent.unknown => 'Notification',
  };
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    this.links = const NotificationLinks.empty(),
    this.details = const NotificationDetails(),
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        links: NotificationLinks.fromJson(json['links']),
        details: NotificationDetails.fromJson(json['details']),
        id: json['id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get relativeTime {
    final age = DateTime.now().difference(createdAt.toLocal());
    if (age.inDays > 0) return '${age.inDays}d ago';
    if (age.inHours > 0) return '${age.inHours}h ago';
    if (age.inMinutes > 0) return '${age.inMinutes}m ago';
    return 'Just now';
  }
}
