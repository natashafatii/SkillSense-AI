import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Shared routing boundary for backend-verified application sessions.
Widget buildPlatformHome({
  required Widget Function(String role) signedInBuilder,
  required Widget signedOutWidget,
}) {
  return _AuthHome(
    signedInBuilder: signedInBuilder,
    signedOutWidget: signedOutWidget,
  );
}

class _AuthHome extends StatefulWidget {
  final Widget Function(String role) signedInBuilder;
  final Widget signedOutWidget;

  const _AuthHome({
    required this.signedInBuilder,
    required this.signedOutWidget,
  });

  @override
  State<_AuthHome> createState() => _AuthHomeState();
}

class _AuthHomeState extends State<_AuthHome> {
  late StreamSubscription<bool> _sub;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _isSignedIn = AuthService.isAuthenticated;
    _sub = AuthService.authStateChanges.listen((signedIn) {
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
      final role = AuthService.getUserRole();
      return widget.signedInBuilder(role);
    }
    return widget.signedOutWidget;
  }
}
