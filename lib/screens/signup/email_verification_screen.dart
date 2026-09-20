import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../login/login_screen.dart';

/// Email verification code input screen.
///
/// Shown after signup to collect the 6-digit OTP that Clerk emailed.
/// Used by both native (clerk_flutter) and web (clerk-js) paths — the
/// [AuthService.verifySignUpCode] method delegates to the correct
/// platform backend.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String role;
  final bool isSignIn;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.role,
  }) : isSignIn = false;

  const EmailVerificationScreen.signIn({super.key, required this.email})
    : role = '',
      isSignIn = true;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _isRecruiter => widget.role.toUpperCase() == 'RECRUITER';
  Color get _accentColor =>
      _isRecruiter ? const Color(0xFF2563EB) : const Color(0xFF0FB89B);
  Color get _accentDarkColor =>
      _isRecruiter ? const Color(0xFF1D4ED8) : const Color(0xFF0D9F86);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Auto-focus the first field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_isLoading) return;
    final code = _code;
    if (code.length != 6) {
      setState(() => _error = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.isSignIn) {
        await AuthService.verifySignInCode(code);
      } else {
        await AuthService.verifySignUpCode(code);
      }
      if (!mounted) return;
      _snack(
        widget.isSignIn
            ? 'Device verified. Signing you in…'
            : 'Email verified! Redirecting…',
      );
      // Navigate to the onboarding walkthrough for first-time users.
      // The onboarding flow will navigate to the dashboard/home on
      // completion and mark the user as onboarded.
      Navigator.of(context).pushNamedAndRemoveUntil(
        widget.role == 'RECRUITER' ? '/dashboard' : '/candidate/home',
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendSignInCode() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await AuthService.resendSignInCode();
      if (mounted) _snack('A new verification code has been sent.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.publicSans(fontWeight: FontWeight.w500),
        ),
        backgroundColor: _accentColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-submit when all 6 digits are entered.
    if (_code.length == 6) {
      _verify();
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFFF8FAFC) : Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isWeb
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated envelope icon ──────────────────────────
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor, _accentDarkColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title / Headline ────────────────────────────────
                Text(
                  'Check your email',
                  style: GoogleFonts.publicSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _accentColor,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Subtitle ────────────────────────────────────────
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.publicSans(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a verification code to\n'),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── 6-digit code input ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (e) => _onKeyDown(i, e),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: GoogleFonts.publicSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _accentColor,
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => _onCodeChanged(i, v),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // ── Error message ───────────────────────────────────
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.publicSans(
                              fontSize: 13,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Verify button with gradient ─────────────────────
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentColor, _accentDarkColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            widget.isSignIn
                                ? 'Verify and Sign In'
                                : 'Verify Email',
                            style: GoogleFonts.publicSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Resend / back link ──────────────────────────────
                if (widget.isSignIn)
                  TextButton(
                    onPressed: _isResending ? null : _resendSignInCode,
                    child: Text(
                      _isResending ? 'Sending…' : 'Resend code',
                      style: GoogleFonts.publicSans(
                        fontSize: 13,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Back to Sign In',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      color: _accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
