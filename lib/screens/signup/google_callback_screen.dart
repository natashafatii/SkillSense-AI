import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import 'aurora_google_profile.dart';

/// Completes OAuth and any required profile details before routing.
class GoogleCallbackScreen extends StatefulWidget {
  const GoogleCallbackScreen({super.key});

  @override
  State<GoogleCallbackScreen> createState() => _GoogleCallbackScreenState();
}

class _GoogleCallbackScreenState extends State<GoogleCallbackScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  TextEditingController? _company;
  List<String> _fields = [];
  String _country = '+92';
  String _initialCountry = '+92';
  String _initialName = '';
  String _initialPhone = '';
  bool _busy = false;
  bool _profileLoaded = false;
  bool _needsProfile = false;
  String? _error;
  late final bool _signIn;
  late final String _returnRoute;

  static const _labels = {
    'sign_in_code': 'Email verification code',
    'first_name': 'First name',
    'last_name': 'Last name',
    'username': 'Username',
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
    _name.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _company?.dispose();
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
    if (_busy) return;
    final editingProfile = _needsProfile;
    if (!editingProfile &&
        _fields.isNotEmpty &&
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final rawPhone = _phone.text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final phone = rawPhone.startsWith('+') ? '+$digits' : '$_country$digits';
    final company = _company?.text.trim();
    if (editingProfile) {
      if (name.length < 2) {
        setState(() => _error = 'Please enter your full name.');
        _nameFocus.requestFocus();
        return;
      }
      if (!RegExp(
        r"^\p{L}[\p{L}\p{M} .’'\-]*$",
        unicode: true,
      ).hasMatch(name)) {
        setState(() => _error = 'Please use a valid name.');
        _nameFocus.requestFocus();
        return;
      }
      if (digits.length < 7 || phone.length > 16) {
        setState(
          () => _error = 'Enter a valid phone number for the selected country.',
        );
        _phoneFocus.requestFocus();
        return;
      }
      if (company != null && company.isEmpty) {
        setState(() => _error = 'Please enter your company name.');
        return;
      }
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
        final fullName = '${AuthService.firstName} ${AuthService.lastName}'
            .trim();
        final missingName =
            AuthService.firstName.isEmpty || AuthService.lastName.isEmpty;
        final String savedPhone;
        var missingCompany = false;
        if (recruiter) {
          final profile = await ProfileService.getRecruiterProfile();
          missingCompany = profile.companyName.trim().isEmpty;
          savedPhone = profile.phone.trim();
        } else {
          final profile = await ProfileService.getCandidateProfile(
            forceRefresh: true,
          );
          if (profile == null) {
            throw StateError('Unable to load your profile. Please retry.');
          }
          savedPhone = profile.phone.trim();
        }
        if (!mounted) return;
        _profileLoaded = true;
        _needsProfile = missingName || missingCompany || savedPhone.isEmpty;
        if (missingCompany) _company = TextEditingController();
        _initialName = _name.text = fullName;
        var nationalPhone = savedPhone;
        for (final code in AuroraGoogleProfile.countries.keys) {
          if (savedPhone.startsWith(code)) {
            _initialCountry = _country = code;
            nationalPhone = savedPhone.substring(code.length);
            break;
          }
        }
        _initialPhone = _phone.text = nationalPhone;
        _fields = [];
        if (_needsProfile) return;
      } else if (editingProfile) {
        if (name != _initialName) {
          final parts = name.split(' ');
          await AuthService.updateUserProfile(
            firstName: parts.first,
            lastName: parts.skip(1).join(' '),
          );
          _initialName = name;
        }
        final profilePatch = {
          if (rawPhone != _initialPhone || _country != _initialCountry)
            'phone': phone,
          if (company != null) 'company_name': company,
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
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(_returnRoute, (_) => false);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to sign out. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsProfile) {
      return AuroraGoogleProfile(
        email: AuthService.email,
        recruiter: AuthService.getUserRole() == 'RECRUITER',
        name: _name,
        phone: _phone,
        nameFocus: _nameFocus,
        phoneFocus: _phoneFocus,
        company: _company,
        country: _country,
        onCountryChanged: (value) => setState(() => _country = value),
        onSubmit: _complete,
        busy: _busy,
        error: _error,
      );
    }
    return Scaffold(
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
                        keyboardType: field == 'sign_in_code'
                            ? TextInputType.number
                            : TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'This field is required.';
                          }
                          if (field == 'sign_in_code' &&
                              !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                            return 'Enter the 6-digit code sent to your email.';
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
}
