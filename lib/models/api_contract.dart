/// Shared wire primitives. Percentages remain 0–100; ratios remain 0–1.
abstract final class ApiValue {
  static double? number(Object? value) {
    if (value == null) return null;
    final result = value is num ? value.toDouble() : double.tryParse('$value');
    if (result == null || !result.isFinite) {
      throw const FormatException('Invalid API number.');
    }
    return result;
  }

  static int integer(Object? value) {
    final number = ApiValue.number(value);
    if (number == null || number != number.truncateToDouble()) {
      throw const FormatException('Invalid API integer.');
    }
    return number.toInt();
  }

  /// Reject ambiguous local timestamps; all wire instants must carry a zone.
  static DateTime? instant(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        !RegExp(
          r'(Z|[+-]\d{2}:?\d{2})$',
          caseSensitive: false,
        ).hasMatch(value)) {
      throw const FormatException(
        'API timestamp requires an explicit timezone.',
      );
    }
    return DateTime.parse(value).toUtc();
  }

  static String timestamp(DateTime value) => value.toUtc().toIso8601String();
}

// Separate types prevent using one resource's concurrency token for another.
extension type ApplicationVersion(int value) {}
extension type QuestionSetRevision(int value) {}
extension type TranscriptSelectionVersion(int value) {}
extension type FeedbackRevision(int value) {}
extension type FeedbackEditVersion(int value) {}
extension type EvidenceRevision(int value) {}

/// Known pending states only. Future states never enable commands or polling.
bool isPendingWorkflowState(String state) => const {
  'QUEUED',
  'PARSING',
  'MATCHING',
  'SCREENING',
  'GENERATING',
  'PENDING',
}.contains(state);

/// History envelopes are endpoint-specific arrays, without an older-page cursor.
class RevisionHistory<T> {
  final List<T> revisions;
  RevisionHistory.fromJson(
    Map<String, dynamic> json,
    String field,
    T Function(Map<String, dynamic>) parse,
  ) : revisions = List.unmodifiable(_read(json[field], parse));

  static List<T> _read<T>(
    Object? rows,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (rows is! List || rows.length > 100) {
      throw const FormatException('Invalid revision history.');
    }
    return rows
        .map((row) => parse(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
