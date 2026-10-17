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

  String get relativeTime {
    final age = DateTime.now().difference(createdAt.toLocal());
    if (age.inDays > 0) return '${age.inDays}d ago';
    if (age.inHours > 0) return '${age.inHours}h ago';
    return '${age.inMinutes < 1 ? 0 : age.inMinutes}m ago';
  }
}
