import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-aware access-token storage.
///
/// - **Mobile (iOS/Android):** persists via [FlutterSecureStorage]
///   (Keychain / Android Keystore).
/// - **Web:** kept in-memory only. [FlutterSecureStorage] on web falls back
///   to `localStorage`, which is readable by any injected script.  Since the
///   access token is short-lived (≈15 min), it is safer to *not* persist it
///   and let the app silently re-authenticate via the httpOnly refresh cookie
///   on page reload.
///
/// The refresh token is **never** stored or read here — on mobile it lives
/// inside the [PersistCookieJar] managed by `dio_cookie_manager`; on web it
/// lives in the browser's own cookie storage.  Dart code intentionally cannot
/// access it (httpOnly).
class TokenStorage {
  TokenStorage._(); // prevent instantiation

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accessKey = 'access_token';

  /// In-memory fallback used only on web.
  static String? _memoryAccessToken;

  /// Persist the access token using the platform-appropriate mechanism.
  static Future<void> saveAccessToken(String token) async {
    if (kIsWeb) {
      _memoryAccessToken = token;
    } else {
      await _storage.write(key: _accessKey, value: token);
    }
  }

  /// Retrieve the current access token, or `null` if none exists.
  static Future<String?> getAccessToken() async {
    if (kIsWeb) return _memoryAccessToken;
    return _storage.read(key: _accessKey);
  }

  /// Wipe the access token on all platforms (used on logout / forced logout).
  static Future<void> clear() async {
    _memoryAccessToken = null;
    if (!kIsWeb) {
      await _storage.delete(key: _accessKey);
    }
  }
}
