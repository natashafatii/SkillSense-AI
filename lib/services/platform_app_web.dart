import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/env_config.dart';
import 'auth_service.dart';

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
  await AuthService.instance.initialize(publishableKey);
}

/// Web: StreamBuilder listening to auth state changes from clerk-js.
Widget buildPlatformHome({
  required Widget Function(String role) signedInBuilder,
  required Widget signedOutWidget,
}) {
  return _WebAuthHome(
    signedInBuilder: signedInBuilder,
    signedOutWidget: signedOutWidget,
  );
}

class _WebAuthHome extends StatefulWidget {
  final Widget Function(String role) signedInBuilder;
  final Widget signedOutWidget;

  const _WebAuthHome({
    required this.signedInBuilder,
    required this.signedOutWidget,
  });

  @override
  State<_WebAuthHome> createState() => _WebAuthHomeState();
}

class _WebAuthHomeState extends State<_WebAuthHome> {
  late StreamSubscription<bool> _sub;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _isSignedIn = AuthService.instance.isSignedIn;
    _sub = AuthService.instance.authStateChanges.listen((signedIn) {
      if (mounted && signedIn != _isSignedIn) {
        setState(() => _isSignedIn = signedIn);
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSignedIn) {
      final role = AuthService.instance.getUserRole(EnvConfig.roleCandidate);
      return widget.signedInBuilder(role);
    }
    return widget.signedOutWidget;
  }
}
