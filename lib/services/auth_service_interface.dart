import 'dart:async';

/// Abstract auth service interface.
///
/// Platform implementations (native via clerk_flutter, web via clerk-js)
/// implement this contract.  The rest of the app interacts only with this
/// interface — never with SDK-specific types directly.
abstract class AuthServiceInterface {
  /// One-time SDK initialisation (called from `main()`).
  Future<void> initialize(String publishableKey);

  /// Email + password sign-in.
  Future<void> login(String email, String password);

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
