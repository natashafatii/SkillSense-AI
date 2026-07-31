import 'dart:io' show Platform;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'auth_interceptor.dart';

/// Centralized Dio HTTP client with platform-aware cookie support.
///
/// **Mobile (iOS / Android):**
/// Uses [PersistCookieJar] via `dio_cookie_manager` to persist the httpOnly
/// refresh cookie between app launches (file-backed under the app-documents
/// directory).
///
/// **Web:**
/// No [CookieManager] needed — the browser's built-in cookie jar handles
/// storage and attachment automatically.  `withCredentials: true` tells the
/// browser to include cookies on cross-origin requests (equivalent to
/// `fetch(url, { credentials: 'include' })`).
class ApiClient {
  ApiClient._(); // prevent instantiation

  static Dio? _dio;

  /// Returns the singleton [Dio] instance, creating it on first call.
  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final baseUrl = _getBaseUrl();

    // ── Main Dio instance ────────────────────────────────────────────────
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // On web, tells the browser to attach/receive cookies cross-origin —
      // the direct equivalent of `credentials: "include"` in a fetch() call.
      extra: <String, dynamic>{'withCredentials': true},
    ));

    // ── Refresh Dio instance (no AuthInterceptor to avoid loops) ─────────
    final refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      extra: <String, dynamic>{'withCredentials': true},
    ));

    if (!kIsWeb) {
      // Mobile has no built-in cookie jar, so PersistCookieJar gives
      // dio_cookie_manager a real place to store the Set-Cookie header
      // between app launches.
      final dir = await getApplicationDocumentsDirectory();
      final cookieJar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cookies/'),
      );
      final cookieManager = CookieManager(cookieJar);

      // Both Dio instances share the same cookie jar so the refresh call
      // has access to the refresh cookie originally set on login.
      dio.interceptors.add(cookieManager);
      refreshDio.interceptors.add(cookieManager);
    }
    // On web, no CookieManager is needed — the browser handles it natively.

    // ── Auth interceptor (silent refresh on 401) ─────────────────────────
    dio.interceptors.add(AuthInterceptor(refreshDio));

    _dio = dio;
    return dio;
  }

  /// Determines the correct base URL based on the runtime platform.
  ///
  /// Android emulators map `10.0.2.2` → host machine's `localhost`.
  static String _getBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      // iOS simulator, macOS, Linux, Windows — all use real localhost.
      return 'http://127.0.0.1:8000/api';
    }
  }

  /// Resets the singleton — useful for testing or after clearing cookies
  /// on logout so the next `getInstance()` creates a fresh Dio with a new
  /// cookie jar.
  static void reset() {
    _dio = null;
  }
}
