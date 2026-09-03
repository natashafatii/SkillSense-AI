import 'package:clerk_flutter/clerk_flutter.dart';

/// Creates a platform-appropriate [ClerkAuthConfig].
///
/// On native platforms, the default persistor (file-system backed) works fine.
/// On web, we provide a web-compatible persistor that uses localStorage,
/// since `path_provider` and `dart:io` are not available.
///
/// This is the stub implementation that is overridden by conditional imports.
ClerkAuthConfig createClerkAuthConfig({required String publishableKey}) {
  // This stub is never used directly — the conditional import selects
  // the correct platform file.
  throw UnsupportedError('Platform not supported');
}
