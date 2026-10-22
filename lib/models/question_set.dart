import 'api_contract.dart';

/// Wire DTO checked against backend QuestionSetDTO. No private input snapshot.
class PreparedQuestion {
  final String id, text, category, source;
  final int position;
  PreparedQuestion.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      text = json['text'] as String,
      category = json['category'] as String,
      source = json['source'] as String,
      position = ApiValue.integer(json['position']);
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'category': category,
    'source': source,
    'position': position,
  };
}

class QuestionSet {
  final String? id, application, assessment;
  final String generationStatus;
  final String errorCode, fallbackReason, inputHash;
  final int attempts, generationNumber;
  final QuestionSetRevision? revision;
  final int? assessmentRevision, frozenRevision;
  final DateTime? approvedAt, frozenAt, nextAttemptAt;
  final bool legacy;
  final List<PreparedQuestion> questions;
  QuestionSet.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String?,
      application = json['application'] as String?,
      assessment = json['assessment'] as String?,
      generationStatus = json['generation_status'] as String? ?? 'UNKNOWN',
      errorCode = json['error_code']?.toString() ?? '',
      fallbackReason = json['fallback_reason']?.toString() ?? '',
      inputHash = json['input_hash']?.toString() ?? '',
      attempts = json['attempts'] == null
          ? 0
          : ApiValue.integer(json['attempts']),
      generationNumber = json['generation_number'] == null
          ? 0
          : ApiValue.integer(json['generation_number']),
      revision = json['revision'] == null
          ? null
          : QuestionSetRevision(ApiValue.integer(json['revision'])),
      assessmentRevision = json['assessment_revision'] == null
          ? null
          : ApiValue.integer(json['assessment_revision']),
      frozenRevision = json['frozen_revision'] == null
          ? null
          : ApiValue.integer(json['frozen_revision']),
      approvedAt = ApiValue.instant(json['approved_at']),
      frozenAt = ApiValue.instant(json['frozen_at']),
      nextAttemptAt = ApiValue.instant(json['next_attempt_at']),
      legacy = json['legacy'] == true,
      questions = List.unmodifiable(
        (json['questions'] as List).map(
          (q) => PreparedQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'application': application,
    'assessment': assessment,
    'assessment_revision': assessmentRevision,
    'revision': revision?.value,
    'generation_status': generationStatus,
    'generation_number': generationNumber,
    'input_hash': inputHash,
    'attempts': attempts,
    'error_code': errorCode,
    'fallback_reason': fallbackReason,
    'approved_at': approvedAt?.toIso8601String(),
    'frozen_at': frozenAt?.toIso8601String(),
    'frozen_revision': frozenRevision,
    'next_attempt_at': nextAttemptAt?.toIso8601String(),
    'legacy': legacy,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  bool get editable =>
      !legacy &&
      frozenAt == null &&
      revision != null &&
      revision!.value > 0 &&
      const {'READY', 'FALLBACK'}.contains(generationStatus);
  bool get schedulable =>
      id != null && id!.isNotEmpty && editable && approvedAt != null && questions.isNotEmpty;
}
