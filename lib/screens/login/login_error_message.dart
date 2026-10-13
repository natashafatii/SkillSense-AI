import 'dart:async';

import 'package:dio/dio.dart';

import '../../services/api_exception.dart';

/// Classifies sign-in failures without ever returning backend or SDK text to UI.
String loginErrorMessage(Object error) {
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

  if (code == 401 ||
      code == 422 ||
      details.contains('form_password_incorrect') ||
      details.contains('password is incorrect') ||
      details.contains('invalid credentials')) {
    return 'Email or password is incorrect. Please try again.';
  }
  if (code == 400 ||
      details.contains('form_param_missing') ||
      details.contains('missing field')) {
    return 'Please enter your email and password.';
  }
  if (code == 429 ||
      details.contains('rate limit') ||
      details.contains('too many attempts') ||
      details.contains('too many requests')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if ((code != null && code >= 500 && code <= 599) ||
      details.contains('server error') ||
      details.contains('service unavailable')) {
    return 'Something went wrong on our end. Please try again shortly.';
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
    return "Couldn't reach the server. Check your connection.";
  }
  return 'Sign-in failed. Please try again.';
}
