class Interview {
  final String id;
  final String applicationId;
  final DateTime? scheduledAt;
  final String status;
  final String questionPreparationMode;
  final String questionFallbackReason;

  const Interview({
    required this.id,
    required this.applicationId,
    this.scheduledAt,
    this.status = 'SCHEDULED',
    this.questionPreparationMode = 'LEGACY_UNVERIFIED',
    this.questionFallbackReason = '',
  });

  factory Interview.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final application =
        json['application']?.toString() ??
        json['application_id']?.toString() ??
        '';
    final scheduled = DateTime.tryParse(
      (json['scheduled_at'] ?? json['scheduled_time'] ?? '').toString(),
    );
    if (id.isEmpty) {
      throw const FormatException('Interview response is missing an ID.');
    }
    return Interview(
      id: id,
      applicationId: application,
      scheduledAt: scheduled,
      status: (json['status'] ?? 'SCHEDULED').toString(),
      questionPreparationMode:
          (json['question_preparation_mode'] ?? 'LEGACY_UNVERIFIED').toString(),
      questionFallbackReason: (json['question_fallback_reason'] ?? '')
          .toString(),
    );
  }
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
