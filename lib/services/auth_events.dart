import 'dart:async';

/// Lightweight broadcast event bus for auth lifecycle events.
///
/// The [AuthInterceptor] (which has no [BuildContext]) fires [forceLogout]
/// when a token refresh attempt fails, signalling the UI layer to navigate
/// the user back to the login screen.
///
/// Usage in the root widget:
/// ```dart
/// AuthEvents.onForceLogout.listen((_) {
///   Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
/// });
/// ```
class AuthEvents {
  AuthEvents._(); // prevent instantiation

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// Stream that emits whenever the app must force-logout.
  static Stream<void> get onForceLogout => _controller.stream;

  /// Trigger a force-logout (called from [AuthInterceptor]).
  static void forceLogout() => _controller.add(null);
}
