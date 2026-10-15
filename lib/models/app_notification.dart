class AppNotification {
  final String id;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get title => switch (type) {
    'application_received' => 'Application received',
    'interview_scheduled' => 'Interview scheduled',
    'score_ready' => 'Score ready',
    'application_status_changed' => 'Application updated',
    _ => 'Notification',
  };
}
