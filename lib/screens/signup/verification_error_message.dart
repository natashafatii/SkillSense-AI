import 'dart:async';

import 'package:dio/dio.dart';

import '../../services/api_exception.dart';

/// Returns fixed, user-facing copy; backend and SDK text stays out of the UI.
String verificationErrorMessage(Object error) {
  final status = switch (error) {
    ApiException(:final statusCode) => statusCode,
    DioException(:final response) => response?.statusCode,
    _ => null,
  };
  final details = error.toString().toLowerCase();
  final embeddedStatus = RegExp(
    r'\b(?:status(?:code)?\s*[:=]?\s*|http\s*|apiexception\()(\d{3})\b',
  ).firstMatch(details);
  final code = status ?? int.tryParse(embeddedStatus?.group(1) ?? '');

  if (code == 422 ||
      details.contains('form_code_incorrect') ||
      details.contains('incorrect code')) {
    return 'Incorrect code. Please try again.';
  }
  if (code == 400 ||
      details.contains('form_param_missing') ||
      details.contains('missing digits')) {
    return 'Please enter the 6-digit code.';
  }
  if (code == 429 ||
      details.contains('rate limit') ||
      details.contains('too many attempts') ||
      details.contains('too many requests')) {
    return 'Too many attempts. Try again in a moment.';
  }
  if ((code != null && code >= 500 && code <= 599) ||
      details.contains('server error') ||
      details.contains('service unavailable')) {
    return 'Something went wrong. Please try again.';
  }
  if (error is TimeoutException ||
      (error is DioException &&
          (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout)) ||
      details.contains('socketexception') ||
      details.contains('failed to fetch') ||
      details.contains('networkerror') ||
      details.contains('xmlhttprequest error') ||
      details.contains('network error') ||
      details.contains('failed to connect') ||
      details.contains('connection timed out') ||
      details.contains('offline')) {
    return "Couldn't reach the server.";
  }
  return 'Verification failed. Please try again.';
}
