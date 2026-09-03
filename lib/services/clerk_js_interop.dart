/// dart:js_interop bindings for Clerk's JavaScript SDK (clerk-js).
///
/// These extension types provide zero-cost, type-safe wrappers around the
/// global `Clerk` object that clerk-js installs on `window`.
///
/// Only the subset of the API needed by [AuthServiceWeb] is surfaced here:
///   - Clerk lifecycle: load, signOut, setActive, addListener
///   - SignUp:  create, prepareEmailAddressVerification,
///              attemptEmailAddressVerification
///   - SignIn:  create
///   - Session: getToken
///   - User:    publicMetadata, unsafeMetadata
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// ═══════════════════════════════════════════════════════════════════════
// Top-level accessors
// ═══════════════════════════════════════════════════════════════════════

/// Returns the global `window.Clerk` object installed by the clerk-js
/// script tag.  Will be `null` until the script has loaded.
@JS('Clerk')
external ClerkJS? get _clerkGlobal;

/// Safe accessor that throws a descriptive error when clerk-js has not
/// finished loading yet.
ClerkJS get clerkInstance {
  final c = _clerkGlobal;
  if (c == null) {
    throw StateError(
      'Clerk JS SDK is not available on window. '
      'Ensure the clerk-js <script> tag is present in web/index.html '
      'and has finished loading before calling this.',
    );
  }
  return c;
}

// ═══════════════════════════════════════════════════════════════════════
// Clerk (root instance)
// ═══════════════════════════════════════════════════════════════════════

@JS()
extension type ClerkJS._(JSObject _) implements JSObject {
  /// `await clerk.load()` — initialises internal state & dev-browser
  /// handshake.
  external JSPromise<JSAny?> load();

  /// The `Client` object containing `signIn` and `signUp` resources.
  external ClerkClient get client;

  /// The active `Session`, or `null` when signed out.
  external ClerkSession? get session;

  /// The active `User`, or `null` when signed out.
  external ClerkUser? get user;

  /// `clerk.setActive({ session })` — makes the given session the active
  /// one.
  external JSPromise<JSAny?> setActive(JSObject params);

  /// `clerk.signOut()` — signs out the current user.
  external JSPromise<JSAny?> signOut();

  /// `clerk.addListener(callback)` — the callback is invoked with the
  /// `ClerkClient` resource whenever auth state changes.
  external void addListener(JSFunction callback);
}

// ═══════════════════════════════════════════════════════════════════════
// Client
// ═══════════════════════════════════════════════════════════════════════

@JS()
extension type ClerkClient._(JSObject _) implements JSObject {
  external ClerkSignUp get signUp;
  external ClerkSignIn get signIn;
}

// ═══════════════════════════════════════════════════════════════════════
// SignUp
// ═══════════════════════════════════════════════════════════════════════

@JS()
extension type ClerkSignUp._(JSObject _) implements JSObject {
  /// `signUp.create({ emailAddress, password, firstName, lastName,
  ///   unsafeMetadata })`.
  external JSPromise<ClerkSignUp> create(JSObject params);

  /// `signUp.prepareEmailAddressVerification({ strategy: 'email_code' })`.
  external JSPromise<ClerkSignUp> prepareEmailAddressVerification(
    JSObject params,
  );

  /// `signUp.attemptEmailAddressVerification({ code })`.
  external JSPromise<ClerkSignUp> attemptEmailAddressVerification(
    JSObject params,
  );

  /// `'complete'`, `'missing_requirements'`, etc.
  external String? get status;

  /// The session id created when status becomes `complete`.
  external String? get createdSessionId;
}

// ═══════════════════════════════════════════════════════════════════════
// SignIn
// ═══════════════════════════════════════════════════════════════════════

@JS()
extension type ClerkSignIn._(JSObject _) implements JSObject {
  /// `signIn.create({ identifier, password })`.
  external JSPromise<ClerkSignIn> create(JSObject params);

  /// `'complete'`, `'needs_first_factor'`, etc.
  external String? get status;

  /// Session id when sign-in is complete.
  external String? get createdSessionId;
}

// ═══════════════════════════════════════════════════════════════════════
// Session
// ═══════════════════════════════════════════════════════════════════════

@JS()
extension type ClerkSession._(JSObject _) implements JSObject {
  external String get id;

  /// `session.getToken()` — returns the session JWT.
  external JSPromise<JSString?> getToken();
}

// ═══════════════════════════════════════════════════════════════════════
// User
// ═══════════════════════════════════════════════════════════════════════

@JS()
extension type ClerkUser._(JSObject _) implements JSObject {
  external String? get id;
  external String? get firstName;
  external String? get lastName;

  /// `user.publicMetadata` — read-only from client, set via backend.
  external JSObject? get publicMetadata;

  /// `user.unsafeMetadata` — readable & writable from client.
  external JSObject? get unsafeMetadata;
}

// ═══════════════════════════════════════════════════════════════════════
// JS object construction helpers
// ═══════════════════════════════════════════════════════════════════════

/// Builds the params object for `signUp.create()`.
JSObject buildSignUpCreateParams({
  required String emailAddress,
  required String password,
  String? firstName,
  String? lastName,
  Map<String, String>? unsafeMetadata,
}) {
  final obj = <String, Object>{
    'emailAddress': emailAddress,
    'password': password,
  };
  if (firstName != null) obj['firstName'] = firstName;
  if (lastName != null) obj['lastName'] = lastName;
  if (unsafeMetadata != null) {
    obj['unsafeMetadata'] = unsafeMetadata.jsify()!;
  }
  return obj.jsify()! as JSObject;
}

/// Builds `{ strategy: 'email_code' }`.
JSObject buildPrepareEmailVerificationParams() {
  return {'strategy': 'email_code'}.jsify()! as JSObject;
}

/// Builds `{ code: '...' }`.
JSObject buildAttemptEmailVerificationParams(String code) {
  return {'code': code}.jsify()! as JSObject;
}

/// Builds `{ identifier, password }` for `signIn.create()`.
JSObject buildSignInCreateParams({
  required String identifier,
  required String password,
}) {
  return {
    'identifier': identifier,
    'password': password,
  }.jsify()! as JSObject;
}

/// Builds `{ session: sessionId }` for `clerk.setActive()`.
JSObject buildSetActiveParams(String sessionId) {
  return {'session': sessionId}.jsify()! as JSObject;
}

/// Reads a string property from an opaque JSObject (e.g. metadata).
String? readStringProperty(JSObject? obj, String key) {
  if (obj == null) return null;
  final value = obj.getProperty(key.toJS);
  if (value == null || value.isUndefinedOrNull) return null;
  return (value as JSString).toDart;
}
