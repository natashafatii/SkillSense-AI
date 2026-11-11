import 'package:flutter/material.dart';

import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/session_scope.dart';
import '../login/login_error_message.dart';
import '../signup/email_verification_screen.dart';
import 'admin_portal.dart';

const adminLoginPath = '/admin/login';
const adminOverviewPath = '/admin/overview';
const _adminRole = 'ADMIN';

Uri? adminLocation(String? name) {
  final uri = Uri.tryParse(name ?? '');
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
    return null;
  }
  return uri.path == adminLoginPath || adminRoutes.containsValue(uri.path)
      ? uri
      : null;
}

String _adminDestination(String? path) =>
    adminRoutes.containsValue(path) ? path! : adminOverviewPath;

enum _Access { checking, signingIn, denied, unavailable, allowed }

/// The same authorization boundary is used for startup and named navigation.
class AdminEntry extends StatefulWidget {
  const AdminEntry({super.key, required this.location, this.analyticsTab});

  final Uri location;
  final String? analyticsTab;

  @override
  State<AdminEntry> createState() => _AdminEntryState();
}

class _AdminEntryState extends State<AdminEntry> {
  _Access _access = _Access.checking;
  bool _signingOut = false;
  bool _replacingStack = false;

  bool get _isLogin => widget.location.path == adminLoginPath;
  String get _destination => _adminDestination(
    _isLogin
        ? widget.location.queryParameters['returnTo']
        : widget.location.path,
  );

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_sessionChanged);
    _verify();
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (_access == _Access.allowed && !_signingOut) _requireSignIn();
  }

  Future<void> _verify() async {
    setState(() => _access = _Access.checking);
    if (!AuthService.instance.isSignedIn) {
      _requireSignIn();
      return;
    }

    try {
      // Revalidate the backend identity even when Clerk has a restored session.
      await AuthService.fetchCurrentUser(forceRefresh: true);
      if (!mounted) return;
      if (!AuthService.isAuthenticated) {
        _requireSignIn();
      } else if (AuthService.getUserRole() != _adminRole) {
        setState(() => _access = _Access.denied);
      } else if (_isLogin) {
        _openDestination();
      } else {
        setState(() => _access = _Access.allowed);
      }
    } catch (error) {
      if (!mounted) return;
      if (!AuthService.instance.isSignedIn ||
          (error is ApiException &&
              (error.statusCode == 401 || error.statusCode == 403))) {
        _requireSignIn();
      } else {
        setState(() => _access = _Access.unavailable);
      }
    }
  }

  void _requireSignIn({bool rememberPage = true}) {
    if (_isLogin) {
      setState(() => _access = _Access.signingIn);
      return;
    }
    setState(() => _access = _Access.checking);
    final login = rememberPage
        ? Uri(
            path: adminLoginPath,
            queryParameters: {'returnTo': _destination},
          ).toString()
        : adminLoginPath;
    _replaceStack(login);
  }

  void _openDestination() => _replaceStack(_destination);

  void _replaceStack(String route) {
    if (_replacingStack) return;
    _replacingStack = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final page = ModalRoute.of(context);
      if (page == null || !page.isActive) return;
      final navigator = Navigator.of(context);
      // Dismiss console dialogs on session loss. A replacement already in
      // progress owns its own access check and should keep its destination.
      navigator.popUntil((route) => route is! PopupRoute || route.isFirst);
      if (page.isCurrent) {
        navigator.pushNamedAndRemoveUntil(route, (_) => false);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final rememberPage = _access != _Access.allowed;
    setState(() => _signingOut = true);
    try {
      await AuthService.signOut();
      if (mounted) _requireSignIn(rememberPage: rememberPage);
    } catch (_) {
      if (!mounted) return;
      if (!AuthService.isAuthenticated) {
        _requireSignIn(rememberPage: rememberPage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_access) {
    _Access.checking => const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
    _Access.signingIn => _AdminSignIn(onSignedIn: _openDestination),
    _Access.denied => _AdminEntryLayout(
      title: 'Access denied',
      children: [
        const Text('This console requires a SkillSense admin account.'),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _signingOut ? null : _signOut,
          child: const Text('Sign out and switch accounts'),
        ),
      ],
    ),
    _Access.unavailable => _AdminEntryLayout(
      title: 'Unable to verify access',
      children: [
        const Text('Check your connection and try again.'),
        const SizedBox(height: 20),
        FilledButton(onPressed: _verify, child: const Text('Retry')),
        TextButton(
          onPressed: _signingOut ? null : _signOut,
          child: const Text('Sign out'),
        ),
      ],
    ),
    _Access.allowed => AdminPortal(
      module: adminRoutes.entries
          .firstWhere((entry) => entry.value == _destination)
          .key,
      initialAnalyticsTab: widget.analyticsTab,
      onSignOut: _signingOut ? null : _signOut,
    ),
  };
}

class _AdminSignIn extends StatefulWidget {
  const _AdminSignIn({required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<_AdminSignIn> createState() => _AdminSignInState();
}

class _AdminSignInState extends State<_AdminSignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your staff email and password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await AuthService.login(
        context,
        email,
        _password.text,
        expectedRole: _adminRole,
      );
      if (!mounted) return;
      if (result.status == SignInResultStatus.verificationRequired) {
        _password.clear();
        final verified = await Navigator.of(context).push<Object>(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen.signIn(
              email: email,
              role: _adminRole,
              returnOnSuccess: true,
            ),
          ),
        );
        if (!mounted) return;
        if (verified is RoleMismatchException) throw verified;
        if (verified != true) return;
      }
      if (AuthService.isAuthenticated &&
          AuthService.getUserRole() == _adminRole) {
        widget.onSignedIn();
      } else {
        setState(() => _error = 'Unable to verify your admin account.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is RoleMismatchException
            ? 'Access denied. Use a SkillSense admin account.'
            : loginErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AdminEntryLayout(
    title: 'Admin sign in',
    children: [
      const Text('Sign in with your SkillSense staff account.'),
      const SizedBox(height: 24),
      AutofillGroup(
        child: Column(
          children: [
            TextField(
              controller: _email,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Staff email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: Text(_submitting ? 'Signing in…' : 'Sign in'),
      ),
    ],
  );
}

class _AdminEntryLayout extends StatelessWidget {
  const _AdminEntryLayout({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('SKILLSENSE ADMIN CONSOLE'),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
