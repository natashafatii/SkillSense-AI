import 'api_contract.dart';

/// Candidate-safe feedback-v1 projection. Never parse recruiter evaluations here.
enum FeedbackState {
  unknown,
  pending,
  failed,
  unavailable,
  unreleased,
  released,
  retracted,
}

Map<String, dynamic> _object(dynamic value) {
  if (value is! Map) throw const FormatException('Invalid feedback object.');
  return Map<String, dynamic>.from(value);
}

String _text(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Missing feedback text or identity.');
  }
  return value;
}

double _number(dynamic value, double maximum) {
  if (value is! num || !value.isFinite || value < 0 || value > maximum) {
    throw const FormatException('Invalid feedback measurement.');
  }
  return value.toDouble();
}

List<T> _items<T>(dynamic value, T Function(dynamic) parse) {
  if (value is! List) throw const FormatException('Invalid feedback list.');
  return value.map(parse).toList(growable: false);
}

class FeedbackDimension {
  final String id, label;
  final double percentage;
  final int assessedAnswers;
  FeedbackDimension.fromJson(Map<String, dynamic> data)
    : id = _text(data['id']),
      label = _text(data['label']),
      percentage = _number(data['percentage'], 100),
      assessedAnswers = _count(data['assessed_answers']);
}

int _count(dynamic value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid evidence count.');
  }
  return value;
}

class FeedbackFinding {
  final String dimensionId, text;
  FeedbackFinding.fromJson(Map<String, dynamic> data, String field)
    : dimensionId = _text(data['dimension_id']),
      text = _text(data[field]);
}

class CandidateFeedbackReport {
  final String id, summary;
  FeedbackRevision get feedbackRevision => FeedbackRevision(revision);
  final int revision, assessedQuestions, totalQuestions;
  final DateTime releasedAt;
  final double? performance;
  final double coverage;
  final List<FeedbackDimension> dimensions;
  final List<FeedbackFinding> strengths, gaps, suggestions;
  final List<String> limitations, publicSuggestions;
  final String? publicSummary;

  CandidateFeedbackReport._(
    Map<String, dynamic> data,
    Map<String, dynamic> summaryData,
    Map<String, dynamic>? guidance,
  ) : id = _text(data['id']),
      revision = _count(data['revision']),
      releasedAt = DateTime.parse(_text(data['released_at'])),
      summary = _text(summaryData['text']),
      performance = summaryData['performance_percentage'] == null
          ? null
          : _number(summaryData['performance_percentage'], 100),
      coverage = _number(summaryData['answer_coverage'], 1),
      assessedQuestions = _count(summaryData['assessed_questions']),
      totalQuestions = _count(summaryData['total_questions']),
      dimensions = _items(
        data['performance_dimensions'],
        (v) => FeedbackDimension.fromJson(_object(v)),
      ),
      strengths = _items(
        data['strengths'],
        (v) => FeedbackFinding.fromJson(_object(v), 'description'),
      ),
      gaps = _items(
        data['gaps'],
        (v) => FeedbackFinding.fromJson(_object(v), 'description'),
      ),
      suggestions = _items(
        data['improvement_suggestions'],
        (v) => FeedbackFinding.fromJson(_object(v), 'action'),
      ),
      limitations = _items(data['limitations'], _text),
      publicSummary = guidance?['summary'] == null
          ? null
          : _text(guidance!['summary']),
      publicSuggestions = guidance?['improvement_suggestions'] == null
          ? const []
          : _items(guidance!['improvement_suggestions'], _text);

  factory CandidateFeedbackReport.fromJson(Map<String, dynamic> data) {
    if (data['contract_version'] != 'FEEDBACK_V1') {
      throw const FormatException('Unsupported feedback report contract.');
    }
    final row = CandidateFeedbackReport._(
      data,
      _object(data['interview_summary']),
      data['recruiter_public_guidance'] == null
          ? null
          : _object(data['recruiter_public_guidance']),
    );
    if (row.revision < 1 || row.assessedQuestions > row.totalQuestions) {
      throw const FormatException('Invalid feedback revision or coverage.');
    }
    return row;
  }
}

class CandidateFeedback {
  final String interviewId, applicationId;
  final FeedbackState state;
  final CandidateFeedbackReport? report;
  CandidateFeedback.fromJson(Map<String, dynamic> data)
    : interviewId = _text(data['interview']),
      applicationId = _text(data['application']),
      state = FeedbackState.values.firstWhere(
        (state) => state.name == data['state']?.toString().toLowerCase(),
        orElse: () => FeedbackState.unknown,
      ),
      report = data['state'] == 'RELEASED'
          ? CandidateFeedbackReport.fromJson(_object(data['report']))
          : null;
}
