import 'package:flutter/material.dart';

import 'auth_service.dart';
export 'auth_home.dart' show buildPlatformHome;

/// Web: no ClerkAuth widget needed — clerk-js manages its own state.
Widget wrapWithPlatformAuth({
  required String publishableKey,
  required Widget child,
}) {
  // On web, clerk-js is loaded via the <script> tag and initialised in
  // initializePlatformAuth().  No wrapping widget needed.
  return child;
}

/// Web: initialise the AuthService instance (which loads clerk-js).
Future<void> initializePlatformAuth(String publishableKey) async {
  await AuthService.initialize(publishableKey);
}
