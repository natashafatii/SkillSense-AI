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

  /// Polls for window.__clerkReady to be set to true by index.html init script
  /// up to ~20 seconds.
  Future<ClerkJS> _waitForClerk() async {
    for (var i = 0; i < 200; i++) {
      final bootstrapError = clerkBootstrapError;
      if (bootstrapError != null && bootstrapError.isNotEmpty) {
        throw StateError('Clerk failed to initialize: $bootstrapError');
      }
      if (isClerkReady) {
        return clerkInstance;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException(
      'Clerk did not finish initializing within 20 seconds.',
    );
  }

  @override
  Future<void> initialize(String publishableKey) async {
    if (_initialised) return;

    // Wait until clerk-js script in index.html finishes initialization and sets __clerkReady.
    _clerk = await _waitForClerk();

    _initialised = true;

    // Listen for auth state changes from clerk-js.
    _clerk.addListener(
      ((JSAny? _) {
        _authStreamController.add(_clerk.user != null);
      }).toJS,
    );

    // Seed the stream with the current signed-in state.
    _authStreamController.add(_clerk.user != null);
  }

  @override
  Future<SignInResult> login(String email, String password) async {
    final client = _clerk.client;
    if (client == null) {
      throw Exception('Clerk Client is not initialized yet.');
    }
    final signInResource = client.signIn;
    if (signInResource == null) {
      throw Exception('Clerk SignIn service is unavailable.');
    }

    try {
      final signIn = await signInResource
          .create(
            buildSignInCreateParams(identifier: email, password: password),
          )
          .toDart;

      if (signIn.status == 'complete') {
        await _activateCompletedSignIn(signIn);
        return const SignInResult.complete();
      }

      if (signIn.status == 'needs_client_trust' ||
          signIn.status == 'needs_second_factor') {
        await _prepareEmailCode(signIn);
        return const SignInResult.verificationRequired();
      }

      throw Exception('Sign-in cannot continue. Status: ${signIn.status}');
    } catch (e) {
      final clean = e
          .toString()
          .replaceAll('JavaScriptError: ', '')
          .replaceAll('Exception: ', '')
          .trim();
      throw Exception(clean.isEmpty ? 'Invalid credentials' : clean);
    }
  }

  Future<void> _prepareEmailCode(ClerkSignIn signIn) async {
    final factors = signIn.supportedSecondFactors?.toDart;
    ClerkSignInSecondFactor? emailFactor;
    if (factors != null) {
      for (final factor in factors) {
        if (factor.strategy == 'email_code' &&
            factor.emailAddressId != null &&
            factor.emailAddressId!.isNotEmpty) {
          emailFactor = factor;
          break;
        }
      }
    }

    if (emailFactor == null) {
      throw Exception(
        'This sign-in requires an additional verification method that is not '
        'available for this account.',
      );
    }

    await signIn
        .prepareSecondFactor(
          buildPrepareSignInEmailCodeParams(emailFactor.emailAddressId!),
        )
        .toDart;
  }

  Future<void> _activateCompletedSignIn(ClerkSignIn signIn) async {
    if (signIn.status != 'complete') {
      throw StateError('Cannot activate an incomplete Clerk sign-in.');
    }
    final sessionId = signIn.createdSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError(
        'Clerk completed sign-in without returning a session ID.',
      );
    }
    await _clerk.setActive(buildSetActiveParams(sessionId)).toDart;
    _authStreamController.add(true);
  }

  @override
  Future<void> verifySignInCode(String code) async {
    final signIn = _clerk.client?.signIn;
    if (signIn == null) {
      throw StateError('There is no pending sign-in to verify.');
    }

    try {
      final result = await signIn
          .attemptSecondFactor(buildAttemptSignInEmailCodeParams(code))
          .toDart;
      if (result.status != 'complete') {
        throw Exception(
          'Verification did not complete sign-in. Status: ${result.status}',
        );
      }
      await _activateCompletedSignIn(result);
    } catch (e) {
      final clean = e
          .toString()
          .replaceAll('JavaScriptError: ', '')
          .replaceAll('Exception: ', '')
          .trim();
      throw Exception(
        clean.isEmpty ? 'The verification code is invalid.' : clean,
      );
    }
  }

  @override
  Future<void> resendSignInCode() async {
    final signIn = _clerk.client?.signIn;
    if (signIn == null) {
      throw StateError('There is no pending sign-in challenge to resend.');
    }
    await _prepareEmailCode(signIn);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final signIn = _clerk.client?.signIn;
    if (signIn == null) {
      throw StateError('Clerk SignIn service is unavailable.');
    }

    try {
      final result = await signIn
          .create(buildPasswordResetCreateParams(email))
          .toDart;
      if (result.status != 'needs_first_factor') {
        throw Exception(
          'Password reset could not be started. Status: ${result.status}',
        );
      }
    } catch (e) {
      throw Exception(_cleanError(e, 'Unable to send the reset code.'));
    }
  }

  @override
  Future<SignInResult> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    final signIn = _clerk.client?.signIn;
    if (signIn == null) {
      throw StateError('There is no pending password reset request.');
    }

    try {
      final result = await signIn
          .attemptFirstFactor(
            buildPasswordResetAttemptParams(
              code: code,
              password: newPassword,
            ),
          )
          .toDart;

      if (result.status == 'complete') {
        await _activateCompletedSignIn(result);
        return const SignInResult.complete();
      }
      if (result.status == 'needs_client_trust' ||
          result.status == 'needs_second_factor') {
        await _prepareEmailCode(result);
        return const SignInResult.verificationRequired();
      }
      throw Exception(
        'Password reset did not complete. Status: ${result.status}',
      );
    } catch (e) {
      throw Exception(_cleanError(e, 'The reset code is invalid or expired.'));
    }
  }

  String _cleanError(Object error, String fallback) {
    final clean = error
        .toString()
        .replaceAll('JavaScriptError: ', '')
        .replaceAll('Exception: ', '')
        .trim();
    return clean.isEmpty ? fallback : clean;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    required String role,
  }) async {
    final client = _clerk.client;
    if (client == null || client.signUp == null) {
      throw Exception('Clerk SignUp service is unavailable.');
    }

    // Step 1: Create the sign-up.
    await client.signUp!
        .create(
          buildSignUpCreateParams(
            emailAddress: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            unsafeMetadata: {'role': role},
          ),
        )
        .toDart;

    // Step 2: Request email verification code.
    await client.signUp!
        .prepareEmailAddressVerification(buildPrepareEmailVerificationParams())
        .toDart;
  }

  @override
  Future<void> verifySignUpCode(String code) async {
    final client = _clerk.client;
    if (client == null || client.signUp == null) {
      throw Exception('Clerk SignUp service is unavailable.');
    }

    final signUp = await client.signUp!
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
  String? get firstName => _initialised ? _clerk.user?.firstName : null;

  @override
  String? get lastName => _initialised ? _clerk.user?.lastName : null;

  @override
  bool get isSignedIn => _initialised && _clerk.user != null;

  @override
  Stream<bool> get authStateChanges => _authStreamController.stream;
}
