import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'session_scope.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Apply this before retaining a response beyond its visible view state.
bool responseAllowsStorage(Response response) =>
    !(response.headers.value('cache-control') ?? '')
        .toLowerCase()
        .split(',')
        .any((directive) => directive.trim().split('=').first == 'no-store');

typedef TokenSupplier = Future<String?> Function();

// Central HTTP client that attaches the Clerk session token to every request.
class ApiClient {
  ApiClient._();

  static String get baseUrl => _getBaseUrl();

  static Dio? _dio;
  static final Dio authenticationClient = Dio(
    BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  static TokenSupplier? _tokenSupplier;

  static void setTokenSupplier(TokenSupplier supplier) {
    _tokenSupplier = supplier;
  }

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final dio = Dio(
      BaseOptions(
        baseUrl: _getBaseUrl(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        extra: <String, dynamic>{'withCredentials': true},
      ),
    );

    dio.interceptors.add(
      ClerkTokenInterceptor(
        tokenSupplier: () => _tokenSupplier?.call() ?? Future.value(null),
      ),
    );

    _dio = dio;
    return dio;
  }

  static String _getBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException(
          'API_BASE_URL must be an HTTP(S) API origin/path without credentials, query, or fragment.',
        );
      }
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://127.0.0.1:8000/api';
    }
  }

  static void reset() {
    _dio = null;
  }
}

// Gets a current SDK token for each request and discards obsolete responses.
class ClerkTokenInterceptor extends Interceptor {
  final TokenSupplier tokenSupplier;

  ClerkTokenInterceptor({required this.tokenSupplier});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final epoch = SessionScope.generation;
    options.extra['sessionGeneration'] = epoch;
    try {
      final token = await tokenSupplier();
      if (epoch != SessionScope.generation) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'Session changed.',
          ),
        );
        return;
      }
      if (token == null || token.isEmpty) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'Please sign in again.',
          ),
        );
        return;
      }
      options.headers['Authorization'] = 'Bearer $token';
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: error,
        ),
      );
      return;
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.extra['sessionGeneration'] !=
        SessionScope.generation) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
          error: 'Session changed.',
        ),
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra['sessionGeneration'] !=
        SessionScope.generation) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.cancel,
          error: 'Session changed.',
        ),
      );
      return;
    }
    handler.next(err);
  }
}
