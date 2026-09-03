import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart' as clerk;

import 'auth_service_interface.dart';
import 'clerk_config_stub.dart'
    if (dart.library.io) 'clerk_config_native.dart';

/// Factory called by the conditional import in `auth_service.dart`.
AuthServiceInterface createAuthService() => AuthServiceNative();

/// Native (iOS / Android) auth service backed by clerk_flutter / clerk_auth.
///
/// Behaviour is identical to the original static `AuthService` class that
/// was here before the platform split — only the shape changed (instance
/// methods implementing [AuthServiceInterface]).
class AuthServiceNative implements AuthServiceInterface {
  clerk.Auth? _auth;
  final StreamController<bool> _authStreamController =
      StreamController<bool>.broadcast();

  @override
  Future<void> initialize(String publishableKey) async {
    final config = createClerkAuthConfig(publishableKey: publishableKey);
    _auth = clerk.Auth(config: config);
    await _auth!.initialize();

    // Seed the initial auth state.
    _authStreamController.add(_auth!.client.user != null);
  }

  clerk.Auth get _requireAuth {
    final auth = _auth;
    if (auth == null) {
      throw StateError(
        'AuthServiceNative has not been initialised. '
        'Call initialize() first.',
      );
    }
    return auth;
  }

  @override
  Future<void> login(String email, String password) async {
    await _requireAuth.attemptSignIn(
      strategy: clerk.Strategy.password,
      identifier: email,
      password: password,
    );
    _authStreamController.add(true);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    required String role,
  }) async {
    await _requireAuth.attemptSignUp(
      strategy: clerk.Strategy.emailCode,
      emailAddress: email,
      password: password,
      passwordConfirmation: password,
      firstName: firstName,
      lastName: lastName,
      metadata: {'role': role},
    );
    // Sign-up is created but not yet verified — the UI must collect the
    // email code and call verifySignUpCode().
  }

  @override
  Future<void> verifySignUpCode(String code) async {
    await _requireAuth.attemptSignUp(
      strategy: clerk.Strategy.emailCode,
      code: code,
    );
    _authStreamController.add(_requireAuth.client.user != null);
  }

  @override
  Future<void> signOut() async {
    try {
      await _requireAuth.signOut();
    } catch (_) {}
    _authStreamController.add(false);
  }

  @override
  Future<String?> getSessionToken() async {
    try {
      final tokenObj = await _requireAuth.sessionToken();
      return tokenObj.jwt;
    } catch (_) {
      return null;
    }
  }

  @override
  String getUserRole([String fallbackRole = 'CANDIDATE']) {
    final user = _auth?.client.user;
    if (user == null) return fallbackRole;

    final pubRole = user.publicMetadata?['role'];
    if (pubRole != null && pubRole.toString().isNotEmpty) {
      return pubRole.toString().toUpperCase();
    }

    final unsafeRole = user.unsafeMetadata?['role'];
    if (unsafeRole != null && unsafeRole.toString().isNotEmpty) {
      return unsafeRole.toString().toUpperCase();
    }

    return fallbackRole;
  }

  @override
  String? get userId => _auth?.client.user?.id;

  @override
  bool get isSignedIn => _auth?.client.user != null;

  @override
  Stream<bool> get authStateChanges => _authStreamController.stream;
}
