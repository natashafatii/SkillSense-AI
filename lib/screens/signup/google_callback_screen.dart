import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

/// Completes OAuth before routing, collecting only missing account details.
class GoogleCallbackScreen extends StatefulWidget {
  const GoogleCallbackScreen({super.key});

  @override
  State<GoogleCallbackScreen> createState() => _GoogleCallbackScreenState();
}

class _GoogleCallbackScreenState extends State<GoogleCallbackScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  List<String> _fields = [];
  bool _busy = true;
  bool _profileLoaded = false;
  String? _error;
  late final bool _signIn;
  late final String _returnRoute;

  static const _labels = {
    'sign_in_code': 'Email verification code',
    'first_name': 'First name',
    'last_name': 'Last name',
    'username': 'Username',
    'phone': 'Phone number (with country code)',
    'company_name': 'Company name',
  };

  @override
  void initState() {
    super.initState();
    _signIn = AuthService.pendingGoogleSignIn;
    _returnRoute = _signIn
        ? '/login'
        : switch (AuthService.pendingGoogleRole) {
            'RECRUITER' => '/signup/hr',
            'CANDIDATE' => '/signup/candidate',
            _ => '/signup/role',
          };
    _complete();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _collect(List<String> fields) {
    for (final field in fields) {
      _controllers.putIfAbsent(field, TextEditingController.new);
    }
    if (mounted) setState(() => _fields = fields);
  }

  Future<void> _complete() async {
    if (_fields.isNotEmpty && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!AuthService.isAuthenticated) {
        final missing = await AuthService.completeGoogleSignUp({
          for (final field in _fields) field: _controllers[field]!.text.trim(),
        });
        if (!mounted) return;
        if (missing.isNotEmpty) {
          _collect(missing);
          return;
        }
      }
      final recruiter = AuthService.getUserRole() == 'RECRUITER';
      if (!_signIn && !_profileLoaded) {
        final missing = <String>[];
        if (AuthService.firstName.isEmpty) missing.add('first_name');
        if (AuthService.lastName.isEmpty) missing.add('last_name');
        if (recruiter) {
          final profile = await ProfileService.getRecruiterProfile();
          if (profile.companyName.trim().isEmpty) missing.add('company_name');
          if (profile.phone.trim().isEmpty) missing.add('phone');
        } else {
          final profile = await ProfileService.getCandidateProfile(
            forceRefresh: true,
          );
          if (profile == null) {
            throw StateError('Unable to load your profile. Please retry.');
          }
          if (profile.phone.trim().isEmpty) missing.add('phone');
        }
        _profileLoaded = true;
        if (!mounted) return;
        _collect(missing);
        if (missing.isNotEmpty) return;
      } else if (!_signIn) {
        final values = {
          for (final field in _fields) field: _controllers[field]!.text.trim(),
        };
        if (values.containsKey('first_name') ||
            values.containsKey('last_name')) {
          await AuthService.updateUserProfile(
            firstName: values['first_name'],
            lastName: values['last_name'],
          );
        }
        final profilePatch = {
          if (values.containsKey('phone')) 'phone': values['phone'],
          if (values.containsKey('company_name'))
            'company_name': values['company_name'],
        };
        if (profilePatch.isNotEmpty) {
          if (recruiter) {
            await ProfileService.updateRecruiterProfile(profilePatch);
          } else {
            await ProfileService.updateCandidateProfile(profilePatch);
          }
        }
      }
      if (!mounted) return;
      AuthService.clearGoogleRedirect();
      Navigator.of(context).pushNamedAndRemoveUntil(
        recruiter ? '/dashboard' : '/candidate/home',
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    setState(() => _busy = true);
    try {
      if (AuthService.instance.isSignedIn) await AuthService.signOut();
      AuthService.clearGoogleRedirect();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          _returnRoute,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to sign out. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _fields.isEmpty
                      ? (_signIn
                            ? 'Completing Google sign-in'
                            : 'Completing Google sign-up')
                      : (_fields.contains('sign_in_code')
                            ? 'Verify your sign-in'
                            : 'Complete your profile'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                for (final field in _fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _controllers[field],
                      enabled: !_busy,
                      decoration: InputDecoration(labelText: _labels[field]),
                      keyboardType: field == 'phone'
                          ? TextInputType.phone
                          : TextInputType.text,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'This field is required.';
                        }
                        if (field == 'sign_in_code' &&
                            !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                          return 'Enter the 6-digit code sent to your email.';
                        }
                        if (field == 'phone' &&
                            !RegExp(r'^\+?\d{7,15}$').hasMatch(value.trim())) {
                          return 'Use 7–15 digits, optionally starting with +.';
                        }
                        return null;
                      },
                    ),
                  ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (_fields.isNotEmpty || AuthService.isAuthenticated)
                    FilledButton(
                      onPressed: _complete,
                      child: Text(_fields.isEmpty ? 'Retry' : 'Continue'),
                    ),
                  TextButton(
                    onPressed: _back,
                    child: Text(
                      _signIn ? 'Back to sign in' : 'Back to sign up',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
