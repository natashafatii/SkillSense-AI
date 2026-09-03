import 'package:flutter/material.dart';

/// Stub — replaced by conditional import.
Widget buildPlatformHome({
  required Widget Function(String role) signedInBuilder,
  required Widget signedOutWidget,
}) {
  throw UnsupportedError('Platform not supported');
}

Future<void> initializePlatformAuth(String publishableKey) {
  throw UnsupportedError('Platform not supported');
}

Widget wrapWithPlatformAuth({
  required String publishableKey,
  required Widget child,
}) {
  throw UnsupportedError('Platform not supported');
}
