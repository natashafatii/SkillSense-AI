import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart' as clerk;

import 'auth_service_interface.dart';
import 'clerk_config_stub.dart' if (dart.library.io) 'clerk_config_native.dart';

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
  late Future<void> Function(String token) sessionValidator;

  Future<void> _validateCompletedSession() async {
    if (_requireAuth.client.user == null ||
        _requireAuth.client.activeSession?.isActive != true) {
      throw StateError('Sign-in has not completed.');
    }
    final token = await _requireAuth.sessionToken();
    await sessionValidator(token.jwt);
    _authStreamController.add(true);
  }

  @override
  Future<void> initialize(String publishableKey) async {
    final config = createClerkAuthConfig(publishableKey: publishableKey);
    _auth = clerk.Auth(config: config);
    await _auth!.initialize();

    // Seed the initial auth state.
    _authStreamController.add(isSignedIn);
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
  Future<SignInResult> login(String email, String password) async {
    await _requireAuth.attemptSignIn(
      strategy: clerk.Strategy.password,
      identifier: email,
      password: password,
    );

    if (_requireAuth.client.user == null) {
      if (_requireAuth.signIn?.needsSecondFactor == true ||
          _requireAuth.signIn?.needsClientTrust == true) {
        await _requireAuth.attemptSignIn(strategy: clerk.Strategy.emailCode);
        return const SignInResult.verificationRequired();
      }
      throw StateError('Sign-in has not completed.');
    }
    await _validateCompletedSession();
    return const SignInResult.complete();
  }

  @override
  Future<void> verifySignInCode(String code) async {
    await _requireAuth.attemptSignIn(
      strategy: clerk.Strategy.emailCode,
      code: code,
    );
    await _validateCompletedSession();
  }

  @override
  Future<void> resendSignInCode() async {
    await _requireAuth.attemptSignIn(strategy: clerk.Strategy.emailCode);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _requireAuth.attemptSignIn(
      strategy: clerk.Strategy.resetPasswordEmailCode,
      identifier: email,
    );
  }

  @override
  Future<SignInResult> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    await _requireAuth.attemptSignIn(
      strategy: clerk.Strategy.resetPasswordEmailCode,
      code: code,
      password: newPassword,
    );
    if (_requireAuth.client.user == null &&
        (_requireAuth.signIn?.needsSecondFactor == true ||
            _requireAuth.signIn?.needsClientTrust == true)) {
      await _requireAuth.attemptSignIn(strategy: clerk.Strategy.emailCode);
      return const SignInResult.verificationRequired();
    }
    await _validateCompletedSession();
    return const SignInResult.complete();
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? companyName,
    required String role,
  }) async {
    final metadata = <String, dynamic>{'role': role};
    if (companyName != null && companyName.trim().isNotEmpty) {
      metadata['company_name'] = companyName.trim();
    }
    await _requireAuth.attemptSignUp(
      strategy: clerk.Strategy.emailCode,
      emailAddress: email,
      password: password,
      passwordConfirmation: password,
      firstName: firstName,
      lastName: lastName,
      metadata: metadata,
    );
    // email code and call verifySignUpCode().
  }

  @override
  Future<void> resendSignUpCode() async {
    await _requireAuth.attemptSignUp(strategy: clerk.Strategy.emailCode);
  }

  @override
  Future<void> verifySignUpCode(String code) async {
    await _requireAuth.attemptSignUp(
      strategy: clerk.Strategy.emailCode,
      code: code,
    );
    await _validateCompletedSession();
  }

  @override
  Future<void> signOut() async {
    await _requireAuth.signOut();
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
  String? get firstName => _auth?.client.user?.firstName;

  @override
  String? get lastName => _auth?.client.user?.lastName;

  @override
  bool get isSignedIn =>
      _auth?.client.user != null &&
      _auth?.client.activeSession?.isActive == true;

  @override
  Stream<bool> get authStateChanges => _authStreamController.stream;
}
