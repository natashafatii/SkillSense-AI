import 'package:flutter/material.dart';
import '../constants/env_config.dart';
import '../services/auth_service.dart';

// Redirects users if their active role isn't authorized for the route.
class RoleGuard extends StatefulWidget {
  final List<String> allowedRoles;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  void _verifyAccess() {
    final currentRole = AuthService.getUserRole();
    if (!widget.allowedRoles.contains(currentRole)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access Denied: You do not have permission to view this page.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        final redirectRoute = currentRole == EnvConfig.roleRecruiter
            ? '/dashboard'
            : '/candidate/home';
        Navigator.of(context).pushReplacementNamed(redirectRoute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = AuthService.getUserRole();
    if (!widget.allowedRoles.contains(currentRole)) {
      // Temporary fallback while post frame callback executes redirect
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return widget.child;
  }
}
