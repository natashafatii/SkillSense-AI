import 'package:dio/dio.dart';

/// Structured API exception containing HTTP status code, user-friendly message,
/// and optional field-level validation errors.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? fieldErrors;

  const ApiException({
    this.statusCode,
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
        message: 'Connection timed out. Please check your internet connection '
            'and verify the backend server is reachable.',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return const ApiException(
        statusCode: null,
        message: 'Failed to connect to backend server. Ensure the server is running.',
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
        message: 'An unexpected network error occurred: ${e.message}',
      );
    }

    final statusCode = response.statusCode;
    final data = response.data;

    if (data is Map<String, dynamic>) {
      // 1. Single 'detail' message
      if (data.containsKey('detail')) {
        return ApiException(
          statusCode: statusCode,
          message: data['detail'].toString(),
        );
      }

      // 2. Field-level validation errors (e.g. {"company_name": ["Required."]})
      final Map<String, dynamic> fieldErrors = {};
      String? firstErrorMessage;

      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          fieldErrors[key] = value.map((v) => v.toString()).toList();
          firstErrorMessage ??= '$key: ${value.first}';
        } else {
          fieldErrors[key] = value.toString();
          firstErrorMessage ??= '$key: $value';
        }
      });

      return ApiException(
        statusCode: statusCode,
        message: firstErrorMessage ?? 'Validation failed.',
        fieldErrors: fieldErrors.isNotEmpty ? fieldErrors : null,
      );
    }

    if (data is String && data.isNotEmpty) {
      return ApiException(
        statusCode: statusCode,
        message: data,
      );
    }

    return ApiException(
      statusCode: statusCode,
      message: 'Server error occurred (HTTP $statusCode).',
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
