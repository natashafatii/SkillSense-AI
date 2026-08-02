import 'package:dio/dio.dart';

import 'api_client.dart';
import 'token_storage.dart';

/// High-level authentication API facade.
///
/// All networking is delegated to [ApiClient]; token persistence is handled
/// by [TokenStorage].  This class exposes clean, domain-level methods that
/// the UI layer calls directly.
class AuthService {
  AuthService._(); // prevent instantiation — all methods are static

  // ══════════════════════════════════════════════════════════════════════════
  // Authentication
  // ══════════════════════════════════════════════════════════════════════════

  /// Authenticates a user and persists the access token.
  ///
  /// The refresh token is returned as an httpOnly `Set-Cookie` header by
  /// the backend and is automatically stored by the cookie jar (mobile) or
  /// the browser (web) — no Dart code touches it.
  ///
  /// Returns the `user` map from the response body on success.
  /// Throws on network / validation errors.
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });

      final data = response.data as Map<String, dynamic>;
      final access = data['access'] as String?;
      if (access != null) {
        await TokenStorage.saveAccessToken(access);
      }

      // Return the user object if present, otherwise the full response
      if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
        return data['user'] as Map<String, dynamic>;
      }
      return data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Logs the user out on both client and server.
  ///
  /// Even if the network call fails (e.g. offline), local state is cleared
  /// so the user is never stuck looking logged-in.
  static Future<void> logout() async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post('/auth/logout/');
    } catch (_) {
      // Best-effort — always clear local state regardless.
    }
    await TokenStorage.clear();
    // Reset the Dio singleton so the next session starts with a fresh
    // cookie jar (prevents stale cookies from a previous session).
    ApiClient.reset();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Registration
  // ══════════════════════════════════════════════════════════════════════════

  /// Registers a new candidate account.
  static Future<Map<String, dynamic>> registerCandidate(
    Map<String, dynamic> candidateData,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.post(
        '/auth/register/candidate/',
        data: candidateData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Registers a new recruiter account.
  static Future<Map<String, dynamic>> registerRecruiter(
    Map<String, dynamic> recruiterData,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.post(
        '/auth/register/recruiter/',
        data: recruiterData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Session check
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetches the currently authenticated user's profile.
  ///
  /// Call this on app startup to decide whether to show the login screen or
  /// go straight to the dashboard.  On web, the first call will 401 (no
  /// in-memory access token after reload), the [AuthInterceptor] will
  /// silently refresh via the httpOnly cookie, and the retried request will
  /// succeed — all before this [Future] completes.
  ///
  /// Returns `null` if no valid session exists (i.e. the user must log in).
  static Future<Map<String, dynamic>?> fetchCurrentUser() async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get('/users/me/');
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Error handling
  // ══════════════════════════════════════════════════════════════════════════

  /// Converts [DioException]s into human-readable [Exception]s.
  static Exception _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return Exception(
        'Connection timed out. Please check your internet connection '
        'and verify the backend is running.',
      );
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception(
        'Failed to connect to the backend. '
        'Ensure the Django server is running.',
      );
    } else if (e.response != null) {
      return _parseResponseError(e.response!);
    } else {
      return Exception('An unexpected error occurred: ${e.message}');
    }
  }

  /// Extracts the first human-readable error message from a non-2xx response.
  static Exception _parseResponseError(Response<dynamic> response) {
    String message = 'An unknown error occurred.';
    final data = response.data;
    if (data != null && data is Map<String, dynamic>) {
      // Django REST / SimpleJWT often returns:
      //   {"detail": "..."} or {"field": ["error1", ...]}
      if (data.containsKey('detail')) {
        message = data['detail'].toString();
      } else if (data.values.isNotEmpty) {
        final firstValue = data.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          message = firstValue.first.toString();
        } else {
          message = firstValue.toString();
        }
      }
    }
    return Exception(message);
  }
}
