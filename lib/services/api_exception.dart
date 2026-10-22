import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:dio/dio.dart';

/// Structured API exception containing HTTP status code, user-friendly message,
/// and optional field-level validation errors.
class ApiException implements Exception {
  final int? statusCode;
  final Object? validationBody;
  final Duration? retryAfter;
  bool get requiresReview => statusCode == 409;
  bool get accessUnavailable => statusCode == 403 || statusCode == 404;
  bool get requiresStateRefresh =>
      requiresReview || statusCode == null || statusCode == 503;

  final String message;
  final Map<String, dynamic>? fieldErrors;

  const ApiException({
    this.statusCode,
    this.validationBody,
    this.retryAfter,
    required this.message,
    this.fieldErrors,
  });

  /// Factory constructor that transforms a [DioException] into a clean [ApiException].
  factory ApiException.fromDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        statusCode: null,
        message:
            'Connection timed out. Please check your internet connection '
            'and verify the backend server is reachable.',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return const ApiException(
        statusCode: null,
        message:
            'Failed to connect to backend server. Ensure the server is running.',
      );
    }

    if (e.type == DioExceptionType.cancel) {
      return const ApiException(
        statusCode: null,
        message: 'Request was cancelled.',
      );
    }

    final response = e.response;
    if (response == null) {
      return ApiException(
        statusCode: null,
        message: 'The request could not be confirmed. Refresh before retrying.',
      );
    }

    final statusCode = response.statusCode;
    final data = response.data;
    final retryHeader = response.headers.value('retry-after');
    Duration? retryAfter;
    if (retryHeader != null) {
      final seconds = int.tryParse(retryHeader);
      if (seconds != null) {
        retryAfter = Duration(seconds: seconds < 0 ? 0 : seconds);
      } else {
        try {
          final delay = parseHttpDate(
            retryHeader,
          ).difference(DateTime.now().toUtc());
          retryAfter = delay.isNegative ? Duration.zero : delay;
        } on FormatException {
          /* Invalid server hint: use bounded backoff. */
        }
      }
    }
    String describe(Object? value) {
      if (value is Map) {
        return value.entries
            .map((e) => '${e.key}: ${describe(e.value)}')
            .join('\n');
      }
      if (value is List) return value.map(describe).join('\n');
      return value?.toString() ?? '';
    }

    final message = describe(
      data is Map && data.containsKey('detail') ? data['detail'] : data,
    );
    return ApiException(
      statusCode: statusCode,
      validationBody: data,
      retryAfter: retryAfter,
      fieldErrors: data is Map ? Map<String, dynamic>.from(data) : null,
      message: message.isNotEmpty
          ? message
          : 'Request failed (HTTP $statusCode).',
    );
  }

  @override
  String toString() {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      return 'ApiException($statusCode: $message, fields: $fieldErrors)';
    }
    return 'ApiException($statusCode: $message)';
  }
}
