import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Verify the current backend identity before constructing a protected screen.
class RoleGuard extends StatefulWidget {
  final List<String> allowedRoles;
  final Widget child;
  const RoleGuard({super.key, required this.allowedRoles, required this.child});
  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _allowed = false;
  String? _error;
  StreamSubscription<bool>? _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = AuthService.authStateChanges.listen((signedIn) {
      if (mounted && !signedIn) {
        setState(() {
          _allowed = false;
          _error = 'Please sign in to access this page.';
        });
      }
    });
    _verifyAccess();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _verifyAccess() async {
    setState(() {
      _allowed = false;
      _error = null;
    });

    try {
      await AuthService.fetchCurrentUser();
      if (!mounted) return;
      final role = AuthService.getUserRole();
      if (widget.allowedRoles.contains(role)) {
        setState(() => _allowed = true);
      } else if (role == 'CANDIDATE' || role == 'RECRUITER') {
        Navigator.of(context).pushReplacementNamed(
          role == 'RECRUITER' ? '/dashboard' : '/candidate/home',
        );
      } else {
        setState(() => _error = 'This account cannot access this page.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to verify access. ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed && widget.allowedRoles.contains(AuthService.getUserRole())) {
      return widget.child;
    }
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                  TextButton(
                    onPressed: _verifyAccess,
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await AuthService.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login/role',
                            (_) => false,
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          setState(() => _error = 'Sign out failed: $error');
                        }
                      }
                    },
                    child: const Text('Back to login'),
                  ),
                ],
              ),
      ),
    );
  }
}
