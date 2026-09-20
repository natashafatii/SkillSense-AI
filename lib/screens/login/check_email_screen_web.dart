import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/web_auth_left_panel.dart';

class CheckEmailScreenWeb extends StatefulWidget {
  final String email;
  final ValueChanged<String> onContinue;
  final VoidCallback onBackToSignIn;
  final VoidCallback onUseDifferentEmail;

  const CheckEmailScreenWeb({
    super.key,
    required this.email,
    required this.onContinue,
    required this.onBackToSignIn,
    required this.onUseDifferentEmail,
  });

  @override
  State<CheckEmailScreenWeb> createState() => _CheckEmailScreenWebState();
}

class _CheckEmailScreenWebState extends State<CheckEmailScreenWeb> {
  static const int _cooldown = 60;
  final TextEditingController _codeController = TextEditingController();
  int _secondsLeft = _cooldown;
  Timer? _timer;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _continue() {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Enter the 6-digit code from the email.';
        _successMessage = null;
      });
      return;
    }
    widget.onContinue(code);
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await AuthService.requestPasswordReset(widget.email);
      if (!mounted) return;
      setState(() => _successMessage = 'A new reset code has been sent.');
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = Responsive.getSpacing(
            context,
            mobile: 24,
            tablet: 32,
            desktop: 32,
          );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    const Positioned.fill(child: WebAuthBackground()),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.webLayoutMaxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            WebAuthLeftPanel(
                              eyebrow: AppConstants.checkEmailWebEyebrow,
                              headline: AppConstants.checkEmailWebHeadline,
                              body: AppConstants.checkEmailWebBody,
                              point1: AppConstants.checkEmailWebPoint1,
                              point2: AppConstants.checkEmailWebPoint2,
                              point3: AppConstants.checkEmailWebPoint3,
                            ),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 40,
                                    horizontal: horizontalPadding,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: Responsive.rightPanelContentMaxWidth,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _MessageBanner(
                                          message: _errorMessage ??
                                              _successMessage ??
                                              'We sent a 6-digit reset code to ${widget.email}.',
                                          isError: _errorMessage != null,
                                        ),
                                        const SizedBox(height: 28),
                                        Text(
                                          AppConstants.checkEmailWebRightTitle,
                                          style: GoogleFonts.inter(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppConstants.checkEmailWebRightSubtitle,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: const Color(0xFF64748B),
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        const WebAuthFieldLabel(label: 'Reset code'),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _codeController,
                                          keyboardType: TextInputType.number,
                                          maxLength: 6,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          onSubmitted: (_) => _continue(),
                                          decoration: InputDecoration(
                                            hintText: '000000',
                                            counterText: '',
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: _continue,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.webLoginButton,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Continue'),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: TextButton(
                                            onPressed: _secondsLeft == 0 && !_isResending
                                                ? _resend
                                                : null,
                                            child: _isResending
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : Text(
                                                    _secondsLeft > 0
                                                        ? 'Resend code in ${_formatTime(_secondsLeft)}'
                                                        : 'Resend code',
                                                  ),
                                          ),
                                        ),
                                        Center(
                                          child: TextButton(
                                            onPressed: widget.onUseDifferentEmail,
                                            child: const Text('Use a different email'),
                                          ),
                                        ),
                                        Center(
                                          child: TextButton(
                                            onPressed: widget.onBackToSignIn,
                                            child: const Text('Back to sign in'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB91C1C) : const Color(0xFF047857);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
