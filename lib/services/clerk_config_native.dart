import 'package:clerk_flutter/clerk_flutter.dart';

/// Native platform implementation — uses the default clerk_flutter persistor
/// which relies on path_provider + dart:io (file system caching).
ClerkAuthConfig createClerkAuthConfig({required String publishableKey}) {
  return ClerkAuthConfig(publishableKey: publishableKey);
}
