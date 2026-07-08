import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/green_gradient_background.dart';
import '../login/login_screen.dart';
import '../../services/auth_service.dart';

const _green = Color(0xFF34C759);

class CandidateRegisterScreen extends StatefulWidget {
  const CandidateRegisterScreen({super.key});

  @override
  State<CandidateRegisterScreen> createState() => _CandidateRegisterScreenState();
}

class _CandidateRegisterScreenState extends State<CandidateRegisterScreen> {
  // ── Visibility toggles ─────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // ── Phone length tracker ───────────────────────────────────────────────────
  int _phoneLength = 0;
  String _phoneNumber = '';

  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────────────────────────
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ── Focus nodes (for animated focus glow) ─────────────────────────────────
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    for (final n in [
      _firstNameFocus,
      _lastNameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      n.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameController,
      _lastNameController,
      _emailController,
      _passwordController,
      _confirmController,
    ]) {
      c.dispose();
    }
    for (final n in [
      _firstNameFocus,
      _lastNameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      n.dispose();
    }
    super.dispose();
  }

  // ── Password strength ──────────────────────────────────────────────────────
  double get _strength {
    final v = _passwordController.text;
    if (v.isEmpty) return 0;
    double s = 0;
    if (v.length >= 8) s += 0.25;
    if (v.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (v.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (v.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  Color get _strengthColor {
    if (_strength <= 0.25) return const Color(0xFFE53935);
    if (_strength <= 0.50) return const Color(0xFFFB8C00);
    if (_strength <= 0.75) return const Color(0xFFFDD835);
    return _green;
  }

  String get _strengthLabel {
    if (_strength <= 0.25) return 'Weak';
    if (_strength <= 0.50) return 'Fair';
    if (_strength <= 0.75) return 'Good';
    return 'Strong';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.publicSans(fontWeight: FontWeight.w500),
        ),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final candidateData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneNumber,
        'password': _passwordController.text,
        'password_confirm': _confirmController.text,
      };
      await AuthService.registerCandidate(candidateData);
      _snack('Registration successful! Please login.');
      // Navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Input decoration (floating label + focus state) ────────────────────────
  InputDecoration _decor(
    String label,
    String hint, {
    Widget? prefix,
    Widget? suffix,
    bool focused = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.publicSans(
        fontSize: 14,
        color: focused ? _green : const Color(0xFF9E9E9E),
        fontWeight: focused ? FontWeight.w600 : FontWeight.w400,
      ),
      floatingLabelStyle: GoogleFonts.publicSans(
        fontSize: 12,
        color: _green,
        fontWeight: FontWeight.w700,
      ),
      hintText: hint,
      hintStyle: GoogleFonts.publicSans(
        fontSize: 13,
        color: const Color(0xFFCFCFCF),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: focused ? Colors.white : const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _green, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
      ),
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      errorStyle: GoogleFonts.publicSans(fontSize: 11),
    );
  }

  // ── Animated glow wrapper ──────────────────────────────────────────────────
  Widget _glow({required Widget child, required bool focused}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _green.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: child,
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF81E291), _green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.publicSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A3C25),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 28,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Section divider ────────────────────────────────────────────────────────
  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFE0E0E0)],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _green.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 12, color: _green),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE0E0E0), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      );



  // ── Prefix icon helper ─────────────────────────────────────────────────────
  Widget _icon(IconData data, {bool focused = false}) => Icon(
        data,
        size: 20,
        color: focused ? _green : const Color(0xFFBDBDBD),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          const GreenGradientBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header on gradient ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: back + badge
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: const Color(0xFFA8D5B5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 17,
                                color: Color(0xFF1A3C25),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Role badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _green.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.work_outline_rounded,
                                  size: 14,
                                  color: _green,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Job Seeker',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Create Account',
                        style: GoogleFonts.publicSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A3C25),
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Fill in the details below to get started',
                        style: GoogleFonts.publicSans(
                          fontSize: 14,
                          color: const Color(0xFF3A6B4A),
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),

                // ── White card ───────────────────────────────────────────────
                Expanded(
                  child: Container(
                    transform: Matrix4.translationValues(0, -8, 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Personal Info ──────────────────────────────────
                            _section('Personal Information', Icons.person_outline_rounded),

                            // First + Last Name
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _glow(
                                    focused: _firstNameFocus.hasFocus,
                                    child: TextFormField(
                                      controller: _firstNameController,
                                      focusNode: _firstNameFocus,
                                      textCapitalization: TextCapitalization.words,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 14,
                                        color: const Color(0xFF212121),
                                      ),
                                      decoration: _decor(
                                        'First Name',
                                        'e.g. Sara',
                                        focused: _firstNameFocus.hasFocus,
                                        prefix: _icon(
                                          Icons.badge_outlined,
                                          focused: _firstNameFocus.hasFocus,
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _glow(
                                    focused: _lastNameFocus.hasFocus,
                                    child: TextFormField(
                                      controller: _lastNameController,
                                      focusNode: _lastNameFocus,
                                      textCapitalization: TextCapitalization.words,
                                      style: GoogleFonts.publicSans(
                                        fontSize: 14,
                                        color: const Color(0xFF212121),
                                      ),
                                      decoration: _decor(
                                        'Last Name',
                                        'e.g. Khan',
                                        focused: _lastNameFocus.hasFocus,
                                        prefix: _icon(
                                          Icons.badge_outlined,
                                          focused: _lastNameFocus.hasFocus,
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),



                            _divider(),

                            // ── Contact Details ────────────────────────────────
                            _section('Contact Details', Icons.contact_mail_outlined),

                            // Email
                            _glow(
                              focused: _emailFocus.hasFocus,
                              child: TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.publicSans(
                                  fontSize: 14,
                                  color: const Color(0xFF212121),
                                ),
                                decoration: _decor(
                                  'Email Address',
                                  'you@example.com',
                                  focused: _emailFocus.hasFocus,
                                  prefix: _icon(
                                    Icons.alternate_email_rounded,
                                    focused: _emailFocus.hasFocus,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Email is required';
                                  }
                                  return RegExp(
                                    r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}",
                                  ).hasMatch(v)
                                      ? null
                                      : 'Enter a valid email';
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone (all countries)
                            IntlPhoneField(
                              style: GoogleFonts.publicSans(
                                fontSize: 14,
                                color: const Color(0xFF212121),
                              ),
                              dropdownTextStyle: GoogleFonts.publicSans(
                                fontSize: 14,
                                color: const Color(0xFF212121),
                              ),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle: GoogleFonts.publicSans(
                                  fontSize: 14,
                                  color: const Color(0xFF9E9E9E),
                                ),
                                floatingLabelStyle: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: _green,
                                  fontWeight: FontWeight.w700,
                                ),
                                hintText: '3XX XXX XXXX',
                                hintStyle: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  color: const Color(0xFFCFCFCF),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8E8E8),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8E8E8),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _green,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                // Phone counter
                                counterText: '$_phoneLength / 10',
                                counterStyle: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _phoneLength >= 10
                                      ? _green
                                      : const Color(0xFFBDBDBD),
                                ),
                              ),
                              initialCountryCode: 'PK',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (phone) {
                                setState(() {
                                  _phoneLength = phone.number.length;
                                  _phoneNumber = phone.completeNumber;
                                });
                              },
                              onCountryChanged: (_) {},
                            ),

                            _divider(),

                            // ── Security ───────────────────────────────────────
                            _section('Security', Icons.shield_outlined),

                            // Password
                            _glow(
                              focused: _passwordFocus.hasFocus,
                              child: TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.publicSans(
                                  fontSize: 14,
                                  color: const Color(0xFF212121),
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: _decor(
                                  'Password',
                                  'Min. 8 characters',
                                  focused: _passwordFocus.hasFocus,
                                  prefix: _icon(
                                    Icons.lock_outline_rounded,
                                    focused: _passwordFocus.hasFocus,
                                  ),
                                  suffix: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF9E9E9E),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Password is required';
                                  }
                                  return v.length >= 8
                                      ? null
                                      : 'Minimum 8 characters';
                                },
                              ),
                            ),

                            // Segmented strength bar
                            if (_passwordController.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ...List.generate(4, (i) {
                                    final segFilled = _strength > i * 0.25;
                                    final segColor = segFilled
                                        ? _strengthColor
                                        : const Color(0xFFEEEEEE);
                                    return Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        margin: EdgeInsets.only(
                                          right: i < 3 ? 4 : 0,
                                        ),
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: segColor,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 10),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: GoogleFonts.publicSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _strengthColor,
                                    ),
                                    child: Text(_strengthLabel),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '8+ chars · uppercase · numbers · symbols',
                                style: GoogleFonts.publicSans(
                                  fontSize: 11,
                                  color: const Color(0xFFBDBDBD),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Confirm Password
                            _glow(
                              focused: _confirmFocus.hasFocus,
                              child: TextFormField(
                                controller: _confirmController,
                                focusNode: _confirmFocus,
                                obscureText: _obscureConfirm,
                                style: GoogleFonts.publicSans(
                                  fontSize: 14,
                                  color: const Color(0xFF212121),
                                ),
                                decoration: _decor(
                                  'Confirm Password',
                                  'Re-enter your password',
                                  focused: _confirmFocus.hasFocus,
                                  prefix: _icon(
                                    Icons.lock_reset_rounded,
                                    focused: _confirmFocus.hasFocus,
                                  ),
                                  suffix: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF9E9E9E),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  return v == _passwordController.text
                                      ? null
                                      : 'Passwords do not match';
                                },
                              ),
                            ),

                            const SizedBox(height: 32),

                            // ── Gradient Register button ───────────────────────
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF81E291),
                                    _green,
                                    Color(0xFF248C3D),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _green.withValues(alpha: 0.45),
                                    blurRadius: 18,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Tappable Terms & Privacy ───────────────────────
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.publicSans(
                                  fontSize: 12,
                                  color: const Color(0xFFAAAAAA),
                                  height: 1.6,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'By registering you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      color: _green,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // TODO: Open Terms
                                      },
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      color: _green,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        // TODO: Open Privacy Policy
                                      },
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Already have account
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppConstants.alreadyAccountPrompt,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 14,
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(
                                        selectedRole: 'jobseeker',
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    AppConstants.loginLinkText,
                                    style: GoogleFonts.publicSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
