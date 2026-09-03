import 'dart:async';
import 'dart:js_interop';

import 'auth_service_interface.dart';
import 'clerk_js_interop.dart';

/// Factory called by the conditional import in `auth_service.dart`.
AuthServiceInterface createAuthService() => AuthServiceWeb();

/// Web auth service backed by Clerk's official JavaScript SDK (clerk-js).
///
/// clerk-js is loaded via a `<script>` tag in `web/index.html` and handles
/// the dev-browser handshake (`__clerk_db_jwt` cookie exchange)
/// automatically — the exact capability missing from the Dart SDK on web.
class AuthServiceWeb implements AuthServiceInterface {
  late ClerkJS _clerk;
  final StreamController<bool> _authStreamController =
      StreamController<bool>.broadcast();
  bool _initialised = false;

  @override
  Future<void> initialize(String publishableKey) async {
    if (_initialised) return;

    // The global `Clerk` object is installed by the script tag.
    // Wait briefly if it hasn't appeared yet (async script loading).
    _clerk = await _waitForClerk();
    await _clerk.load().toDart;
    _initialised = true;

    // Listen for auth state changes from clerk-js.
    _clerk.addListener(
      ((JSAny? _) {
        _authStreamController.add(_clerk.user != null);
      }).toJS,
    );

    // Seed initial state.
    _authStreamController.add(_clerk.user != null);
  }

  /// Polls for the global `window.Clerk` object up to ~5 seconds,
  /// since the script tag loads asynchronously.
  Future<ClerkJS> _waitForClerk() async {
    for (var i = 0; i < 50; i++) {
      try {
        return clerkInstance;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return clerkInstance; // Will throw descriptive error.
  }

  @override
  Future<void> login(String email, String password) async {
    final signIn = await _clerk.client.signIn
        .create(buildSignInCreateParams(
          identifier: email,
          password: password,
        ))
        .toDart;

    if (signIn.status == 'complete') {
      final sessionId = signIn.createdSessionId;
      if (sessionId != null) {
        await _clerk.setActive(buildSetActiveParams(sessionId)).toDart;
      }
      _authStreamController.add(true);
    } else {
      throw Exception(
        'Sign-in did not complete. Status: ${signIn.status}',
      );
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    required String role,
  }) async {
    // Step 1: Create the sign-up.
    await _clerk.client.signUp
        .create(buildSignUpCreateParams(
          emailAddress: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          unsafeMetadata: {'role': role},
        ))
        .toDart;

    // Step 2: Request email verification code.
    await _clerk.client.signUp
        .prepareEmailAddressVerification(
          buildPrepareEmailVerificationParams(),
        )
        .toDart;

    // The UI must now collect the OTP code from the user and call
    // verifySignUpCode().
  }

  @override
  Future<void> verifySignUpCode(String code) async {
    final signUp = await _clerk.client.signUp
        .attemptEmailAddressVerification(
          buildAttemptEmailVerificationParams(code),
        )
        .toDart;

    if (signUp.status == 'complete') {
      final sessionId = signUp.createdSessionId;
      if (sessionId != null) {
        await _clerk.setActive(buildSetActiveParams(sessionId)).toDart;
      }
      _authStreamController.add(true);
    } else {
      throw Exception(
        'Sign-up verification did not complete. Status: ${signUp.status}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _clerk.signOut().toDart;
    _authStreamController.add(false);
  }

  @override
  Future<String?> getSessionToken() async {
    final session = _clerk.session;
    if (session == null) return null;
    final token = await session.getToken().toDart;
    return token?.toDart;
  }

  @override
  String getUserRole([String fallbackRole = 'CANDIDATE']) {
    final user = _clerk.user;
    if (user == null) return fallbackRole;

    // Check unsafeMetadata first (set by the frontend during sign-up),
    // then publicMetadata (set by backend/webhook).
    final unsafeRole = readStringProperty(user.unsafeMetadata, 'role');
    if (unsafeRole != null && unsafeRole.isNotEmpty) {
      return unsafeRole.toUpperCase();
    }

    final pubRole = readStringProperty(user.publicMetadata, 'role');
    if (pubRole != null && pubRole.isNotEmpty) {
      return pubRole.toUpperCase();
    }

    return fallbackRole;
  }

  @override
  String? get userId => _initialised ? _clerk.user?.id : null;

  @override
  bool get isSignedIn => _initialised && _clerk.user != null;

  @override
  Stream<bool> get authStateChanges => _authStreamController.stream;
}
