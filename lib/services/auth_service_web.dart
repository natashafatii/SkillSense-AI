import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'auth_service_interface.dart';
import 'clerk_js_interop.dart';

/// Factory called by the conditional import in `auth_service.dart`.
AuthServiceInterface createAuthService() => AuthServiceWeb();

/// Web auth service backed by Clerk's official JavaScript SDK (clerk-js).
///
/// clerk-js is loaded via a `<script>` tag in `web/index.html` and handles
/// the dev-browser handshake (`__clerk_db_jwt` cookie exchange)
/// automatically — the exact capability missing from the Dart SDK on web.
class AuthServiceWeb
    implements AuthServiceInterface, GoogleOAuthService, GoogleSignInService {
  late ClerkJS _clerk;
  final StreamController<bool> _authStreamController =
      StreamController<bool>.broadcast();
  bool _initialised = false;
  bool _googleCallbackHandled = false;
  bool _googleEmailCodePrepared = false;
  static const _googleStorageKey = 'skillsense_google_signup';

  @override
  bool get isGoogleCallback =>
      Uri.base.queryParameters['skillsense_oauth'] == 'google' ||
      Uri.base.fragment == '/oauth/callback';

  Map<String, dynamic>? get _googleAttempt {
    try {
      final raw = web.window.sessionStorage.getItem(_googleStorageKey);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final started = DateTime.fromMillisecondsSinceEpoch(
        data['started'] as int,
      );
      final age = DateTime.now().difference(started);
      if (age.isNegative || age > const Duration(minutes: 30)) return null;
      final automaticRole = data['sign_in'] == true && data['role'] == null;
      if (!automaticRole && !['CANDIDATE', 'RECRUITER'].contains(data['role'])) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get pendingGoogleRole => _googleAttempt?['role'] as String?;

  @override
  bool get pendingGoogleSignIn => _googleAttempt?['sign_in'] == true;

  @override
  Future<void> startGoogleSignIn({String? role}) =>
      _startGoogle(role: role, signIn: true);

  String get _googleCallbackUrl => Uri.base
      .replace(
        queryParameters: {'skillsense_oauth': 'google'},
        fragment: '/oauth/callback',
      )
      .toString();

  @override
  Future<void> startGoogleSignUp({required String role, String? companyName}) =>
      _startGoogle(role: role, companyName: companyName);

  Future<void> _startGoogle({
    String? role,
    String? companyName,
    bool signIn = false,
  }) async {
    if (!(signIn && role == null) &&
        !['CANDIDATE', 'RECRUITER'].contains(role)) {
      throw ArgumentError('Choose Candidate or Recruiter to continue.');
    }
    final client = _clerk.client;
    if (client == null ||
        (signIn ? client.signIn == null : client.signUp == null)) {
      throw StateError('Clerk authentication is unavailable.');
    }
    final metadata = {
      'role': role,
      if (companyName != null && companyName.trim().isNotEmpty)
        'company_name': companyName.trim(),
    };
    // Tab-scoped storage survives Google's full-page redirect without sharing
    // the selected portal between tabs. It is never used to authorize a role.
    web.window.sessionStorage.setItem(
      _googleStorageKey,
      jsonEncode({
        ...metadata,
        'sign_in': signIn,
        'started': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    _googleCallbackHandled = false;
    _googleEmailCodePrepared = false;
    try {
      final params =
          {
                'strategy': 'oauth_google',
                'redirectUrl': _googleCallbackUrl,
                'redirectUrlComplete': _googleCallbackUrl,
                if (!signIn) 'unsafeMetadata': metadata,
              }.jsify()!
              as JSObject;
      if (signIn) {
        await client.signIn!.authenticateWithRedirect(params).toDart;
      } else {
        await client.signUp!.authenticateWithRedirect(params).toDart;
      }
    } catch (error) {
      clearGoogleRedirect();
      throw Exception(
        _cleanError(error, 'Unable to start Google authentication.'),
      );
    }
  }

  @override
  Future<List<String>> completeGoogleSignUp(Map<String, String> fields) async {
    final attempt = _googleAttempt;
    if (attempt == null || !isGoogleCallback) {
      throw StateError('Google sign-up expired. Please start again.');
    }
    if (!_googleCallbackHandled) {
      await _clerk
          .handleRedirectCallback(
            {
                  'signInForceRedirectUrl': _googleCallbackUrl,
                  'signUpForceRedirectUrl': _googleCallbackUrl,
                  'continueSignUpUrl': _googleCallbackUrl,
                  'signInUrl': _googleCallbackUrl,
                  'signUpUrl': _googleCallbackUrl,
                  'transferable': !pendingGoogleSignIn,
                  'reloadResource': pendingGoogleSignIn ? 'signIn' : 'signUp',
                  // Clerk 6.39 uses this hook for successful session activation;
                  // customNavigate below only handles incomplete-flow navigation.
                  '__internal_navigateOnSetActive':
                      ((JSObject _) => Future<JSAny?>.value(null).toJS).toJS,
                  if (!pendingGoogleSignIn)
                    'unsafeMetadata': {
                      'role': attempt['role'],
                      if (attempt['company_name'] != null)
                        'company_name': attempt['company_name'],
                    },
                }.jsify()!
                as JSObject,
            // Flutter owns navigation, and publishes auth only after Django agrees.
            ((JSString _) => Future<JSAny?>.value(null).toJS).toJS,
          )
          .toDart;
      _googleCallbackHandled = true;
    }

    if (!isSignedIn) {
      if (pendingGoogleSignIn ||
          _clerk.client?.signUp?.verifications?.externalAccount?.status ==
              'transferable') {
        final signIn = _clerk.client?.signIn;
        if (signIn?.status == 'complete') {
          await _activateCompletedSignIn(signIn!);
          return [];
        }
        if (signIn != null &&
            [
              'needs_second_factor',
              'needs_client_trust',
            ].contains(signIn.status)) {
          final code = fields['sign_in_code']?.trim() ?? '';
          if (code.isNotEmpty) {
            await verifySignInCode(code);
            return [];
          }
          if (!_googleEmailCodePrepared) {
            await _prepareEmailCode(signIn);
            _googleEmailCodePrepared = true;
          }
          return ['sign_in_code'];
        }
        throw StateError(
          'Google sign-in could not complete. Use your existing '
          'email login for additional verification, or sign up if you do not have an account.',
        );
      }
      var signUp = _clerk.client?.signUp;
      if (signUp?.status == 'missing_requirements') {
        final missing =
            signUp!.missingFields?.toDart
                .map((value) => value.toDart)
                .toList() ??
            <String>[];
        const supported = {'first_name', 'last_name', 'username'};
        if (missing.isEmpty ||
            missing.any((field) => !supported.contains(field))) {
          throw StateError(
            'This account requires additional verification. '
            'Please use email sign-up or sign in to your existing account.',
          );
        }
        if (missing.any((field) => (fields[field] ?? '').trim().isEmpty)) {
          return missing;
        }
        const names = {
          'first_name': 'firstName',
          'last_name': 'lastName',
          'username': 'username',
        };
        signUp = await signUp
            .update(
              {
                    for (final field in missing)
                      names[field]!: fields[field]!.trim(),
                  }.jsify()!
                  as JSObject,
            )
            .toDart;
      }
      if (signUp?.status == 'complete' && signUp?.createdSessionId != null) {
        await _activateSession(signUp!.createdSessionId!);
        return [];
      }
      throw StateError(
        'Google sign-in was cancelled or requires additional '
        'verification. Please try again or use your existing login.',
      );
    }
    final token = await getSessionToken();
    if (token == null || token.isEmpty) {
      throw StateError('Google sign-in did not create a valid session.');
    }
    await sessionValidator(token);
    return [];
  }

  @override
  void clearGoogleRedirect() {
    web.window.sessionStorage.removeItem(_googleStorageKey);
    if (isGoogleCallback) {
      final query = Map<String, String>.from(Uri.base.queryParameters)
        ..remove('skillsense_oauth');
      web.window.history.replaceState(
        null,
        '',
        Uri.base
            .replace(
              queryParameters: query.isEmpty ? null : query,
              query: query.isEmpty ? '' : null,
              fragment: '',
            )
            .toString(),
      );
    }
  }

  @override
  late Future<void> Function(String token) sessionValidator;

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
        _authStreamController.add(isSignedIn);
      }).toJS,
    );

    // Seed the stream with the current signed-in state.
    _authStreamController.add(isSignedIn);
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
      if (e is RoleMismatchException) rethrow;
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
    await _activateSession(sessionId);
  }

  Future<void> _activateSession(String sessionId) async {
    final sessions = _clerk.client?.sessions?.toDart;
    final matches = sessions?.where((session) => session.id == sessionId);
    if (matches == null || matches.isEmpty) {
      throw StateError('Clerk did not provide the completed session.');
    }
    final session = matches.first;
    try {
      if (session.status != 'active') {
        throw StateError(
          'This account requires additional Clerk session steps.',
        );
      }
      final token = (await session.getToken().toDart)?.toDart;
      if (token == null || token.isEmpty) {
        throw StateError('Clerk did not provide a session token.');
      }
      await sessionValidator(token);
      await _clerk.setActive(buildSetActiveParams(sessionId)).toDart;
    } catch (_) {
      try {
        await session.remove().toDart;
      } catch (_) {}
      rethrow;
    }
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
      if (e is RoleMismatchException) rethrow;
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
            buildPasswordResetAttemptParams(code: code, password: newPassword),
          )
          .toDart;

      if (result.status == 'complete') {
        // Validate role BEFORE activating the session — a recruiter must not
        // be able to reach the recruiter dashboard via the candidate reset flow.
        await _activateCompletedSignIn(result);
        return const SignInResult.complete();
      }
      if (result.status == 'needs_client_trust' ||
          result.status == 'needs_second_factor') {
        // Carry the role expectation into the OTP-verification step so
        // verifySignInCode() → _activateCompletedSignIn() can also enforce it.
        await _prepareEmailCode(result);
        return const SignInResult.verificationRequired();
      }
      throw Exception(
        'Password reset did not complete. Status: ${result.status}',
      );
    } catch (e) {
      if (e is RoleMismatchException) rethrow;
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
    String? companyName,
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
            unsafeMetadata: {
              'role': role,
              if (companyName != null && companyName.trim().isNotEmpty)
                'company_name': companyName.trim(),
            },
          ),
        )
        .toDart;

    // Step 2: Request email verification code.
    await client.signUp!
        .prepareEmailAddressVerification(buildPrepareEmailVerificationParams())
        .toDart;
  }

  @override
  Future<void> resendSignUpCode() async {
    final client = _clerk.client;
    if (client == null || client.signUp == null) {
      throw StateError('There is no pending sign-up challenge to resend.');
    }
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
      if (sessionId == null) {
        throw StateError('Clerk did not create a session.');
      }
      await _activateSession(sessionId);
    } else {
      throw Exception(
        'Sign-up verification did not complete. Status: ${signUp.status}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _clerk.signOut((() {}).toJS).toDart;
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
  bool get isSignedIn =>
      _initialised && _clerk.user != null && _clerk.session?.status == 'active';

  @override
  Stream<bool> get authStateChanges => _authStreamController.stream;
}
