import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

// Conditional import for ClerkAuthConfig factory (persistor differences).
import 'clerk_config_stub.dart'
    if (dart.library.io) 'clerk_config_native.dart';

/// Native: wrap the app in the `ClerkAuth` InheritedWidget.
Widget wrapWithPlatformAuth({
  required String publishableKey,
  required Widget child,
}) {
  return ClerkAuth(
    config: createClerkAuthConfig(publishableKey: publishableKey),
    child: child,
  );
}

/// Native: initialise the AuthService instance.
Future<void> initializePlatformAuth(String publishableKey) async {
  await AuthService.instance.initialize(publishableKey);
}

/// Native: use ClerkAuthBuilder for auth-state-dependent home widget.
Widget buildPlatformHome({
  required Widget Function(String role) signedInBuilder,
  required Widget signedOutWidget,
}) {
  return ClerkAuthBuilder(
    signedInBuilder: (context, authState) {
      final role = AuthService.getUserRole(authState.user);
      return signedInBuilder(role);
    },
    signedOutBuilder: (context, authState) => signedOutWidget,
  );
}
