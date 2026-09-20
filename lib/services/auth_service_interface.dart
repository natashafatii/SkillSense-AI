import 'dart:async';

enum SignInResultStatus { complete, verificationRequired }

class SignInResult {
  final SignInResultStatus status;

  const SignInResult._(this.status);

  const SignInResult.complete() : this._(SignInResultStatus.complete);

  const SignInResult.verificationRequired()
    : this._(SignInResultStatus.verificationRequired);
}

/// Abstract auth service interface.
///
/// Platform implementations (native via clerk_flutter, web via clerk-js)
/// implement this contract.  The rest of the app interacts only with this
/// interface — never with SDK-specific types directly.
abstract class AuthServiceInterface {
  /// One-time SDK initialisation (called from `main()`).
  Future<void> initialize(String publishableKey);

  /// Email + password sign-in.
  /// Starts an email/password sign-in.
  ///
  /// A successful password check can still require an email code when Clerk
  /// Device Trust sees a new browser. In that case the implementation prepares
  /// the email-code challenge and returns [SignInResultStatus.verificationRequired].
  Future<SignInResult> login(String email, String password);

  /// Completes a pending sign-in email-code challenge.
  Future<void> verifySignInCode(String code) {
    throw UnsupportedError(
      'Sign-in verification is not supported on this platform.',
    );
  }

  /// Sends a new code for the current pending sign-in challenge.
  Future<void> resendSignInCode() {
    throw UnsupportedError(
      'Resending a sign-in code is not supported on this platform.',
    );
  }

  /// Starts Clerk's password-reset flow and sends a code to [email].
  Future<void> requestPasswordReset(String email);

  /// Verifies the reset [code], changes the password, and completes sign-in.
  Future<SignInResult> resetPassword({
    required String code,
    required String newPassword,
  });

  /// Email + password sign-up with role metadata.
  ///
  /// After this call completes the sign-up is created but **not yet verified**
  /// (Clerk requires an email-code verification step).  Call
  /// [verifySignUpCode] next with the OTP the user received.
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    required String role,
  });

  /// Submit the 6-digit email verification code that Clerk sent after
  /// [signUp].  On success the session becomes active automatically.
  Future<void> verifySignUpCode(String code);

  /// Sign out the current session and clear local state.
  Future<void> signOut();

  /// Returns a fresh Clerk session JWT for authenticating API calls.
  Future<String?> getSessionToken();

  /// Returns the role string for the currently signed-in user
  /// (reads `unsafeMetadata.role` / `publicMetadata.role`).
  ///
  /// Falls back to [fallbackRole] when no metadata is present.
  String getUserRole([String fallbackRole = 'CANDIDATE']);

  /// Returns the unique ID of the currently signed-in user, or null if signed out.
  String? get userId;

  /// `true` when there is an active Clerk session.
  bool get isSignedIn;

  /// Broadcasts `true` / `false` whenever the signed-in state changes.
  Stream<bool> get authStateChanges;
}
