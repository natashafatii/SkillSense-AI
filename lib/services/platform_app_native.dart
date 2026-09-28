import 'package:flutter/material.dart';
import 'auth_service.dart';
export 'auth_home.dart' show buildPlatformHome;

// One SDK instance is owned by AuthService; routing observes verified state.
Widget wrapWithPlatformAuth({
  required String publishableKey,
  required Widget child,
}) => child;
Future<void> initializePlatformAuth(String publishableKey) =>
    AuthService.initialize(publishableKey);
