import 'package:dio/dio.dart';

import 'auth_events.dart';
import 'token_storage.dart';

/// Dio interceptor that implements the silent-refresh flow:
///
/// 1. **onRequest** — attaches `Authorization: Bearer <access>` to every
///    outgoing request (if an access token exists in [TokenStorage]).
///
/// 2. **onError** — on a 401 from a *non-auth* endpoint:
///    a. Calls `POST /auth/refresh/` — the refresh cookie is carried
///       automatically (mobile: [CookieManager], web: browser).
///    b. Saves the new access token from the response body.
///    c. Retries the original failed request with the fresh token.
///    d. On refresh failure: clears [TokenStorage] and fires
///       [AuthEvents.forceLogout] so the UI navigates to login.
///
/// The [_isRefreshing] guard prevents concurrent refresh calls when multiple
/// requests 401 simultaneously — critical when the backend has
/// `ROTATE_REFRESH_TOKENS` enabled, since only the first refresh succeeds;
/// the rest would see a blacklisted-token error.
class AuthInterceptor extends Interceptor {
  /// A *separate* [Dio] instance used exclusively for the refresh call.
  ///
  /// We must NOT use the main app [Dio] for refreshing because it carries
  /// this very interceptor — that would cause an infinite loop on 401.
  final Dio _refreshDio;

  bool _isRefreshing = false;

  /// [refreshDio] should share the same [BaseOptions] (especially
  /// `baseUrl` and `extra['withCredentials']`) and [CookieManager]
  /// interceptor as the main [Dio], but must **not** include this
  /// [AuthInterceptor].
  AuthInterceptor(this._refreshDio);

  // ────────────────────────────────────────────────────────────────────────
  // Attach access token to every outgoing request
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await TokenStorage.getAccessToken();
    if (access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Intercept 401s and attempt a silent refresh
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthEndpoint = err.requestOptions.path.contains('/auth/');

    if (err.response?.statusCode == 401 &&
        !isAuthEndpoint &&
        !_isRefreshing) {
      _isRefreshing = true;
      try {
        // Cookie is attached automatically (mobile: CookieManager,
        // web: browser) — nothing to pass explicitly here.
        final refreshResponse = await _refreshDio.post('/auth/refresh/');
        final newAccess = refreshResponse.data['access'] as String;
        await TokenStorage.saveAccessToken(newAccess);

        // Retry the original request with the fresh access token.
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await _refreshDio.fetch(err.requestOptions);
        _isRefreshing = false;
        return handler.resolve(retryResponse);
      } catch (_) {
        _isRefreshing = false;
        await TokenStorage.clear();
        // Signal the UI to navigate to the login screen.
        AuthEvents.forceLogout();
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}
