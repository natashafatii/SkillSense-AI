import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

typedef TokenSupplier = Future<String?> Function();

// Central HTTP client that attaches the Clerk session token to every request.
class ApiClient {
  ApiClient._();

  static Dio? _dio;
  static TokenSupplier? _tokenSupplier;

  static void setTokenSupplier(TokenSupplier supplier) {
    _tokenSupplier = supplier;
  }

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final dio = Dio(BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      extra: <String, dynamic>{'withCredentials': true},
    ));

    dio.interceptors.add(ClerkTokenInterceptor(
      tokenSupplier: () => _tokenSupplier?.call() ?? Future.value(null),
    ));

    _dio = dio;
    return dio;
  }

  static String _getBaseUrl() {
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

// Automatically adds Authorization header and retries once on 401.
class ClerkTokenInterceptor extends Interceptor {
  final TokenSupplier tokenSupplier;

  ClerkTokenInterceptor({required this.tokenSupplier});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await tokenSupplier();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Proceed without header if token fetching fails
    }

    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final options = err.requestOptions;
      final retried = options.extra['retried'] == true;

      if (!retried) {
        options.extra['retried'] = true;
        try {
          final newToken = await tokenSupplier();
          if (newToken != null && newToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $newToken';
            final dio = await ApiClient.getInstance();
            final response = await dio.fetch(options);
            return handler.resolve(response);
          }
        } catch (_) {
          // Token refresh failed, pass error down
        }
      }
    }

    super.onError(err, handler);
  }
}

