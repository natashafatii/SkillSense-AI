import 'auth_service_interface.dart';

/// Stub factory — the conditional import in `auth_service.dart` replaces
/// this with the platform-correct implementation at compile time.
AuthServiceInterface createAuthService() {
  throw UnsupportedError(
    'Cannot create AuthService — no platform implementation selected. '
    'This stub should never execute; check your conditional imports.',
  );
}
