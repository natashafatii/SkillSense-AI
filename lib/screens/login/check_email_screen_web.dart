import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/web_auth_left_panel.dart';


class CheckEmailScreenWeb extends StatefulWidget {
  final String email;
  final VoidCallback onBackToSignIn;
  final VoidCallback onUseDifferentEmail;

  const CheckEmailScreenWeb({
    super.key,
    required this.email,
    required this.onBackToSignIn,
    required this.onUseDifferentEmail,
  });

  @override
  State<CheckEmailScreenWeb> createState() => _CheckEmailScreenWebState();
}

class _CheckEmailScreenWebState extends State<CheckEmailScreenWeb> {
  static const int _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = Responsive.getSpacing(
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
                    Positioned.fill(child: const WebAuthBackground()),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.webLayoutMaxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // LEFT PANEL
                            WebAuthLeftPanel(
                              eyebrow: AppConstants.checkEmailWebEyebrow,
                              headline: AppConstants.checkEmailWebHeadline,
                              body: AppConstants.checkEmailWebBody,
                              point1: AppConstants.checkEmailWebPoint1,
                              point2: AppConstants.checkEmailWebPoint2,
                              point3: AppConstants.checkEmailWebPoint3,
                            ),

                            // RIGHT PANEL
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 40,
                                      horizontal: horizontalPadding,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth:
                                            Responsive.rightPanelContentMaxWidth,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // ── Success banner ──────────────
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFF6EE7B7),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.check_circle_outline,
                                                  color: Color(0xFF10B981),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        AppConstants
                                                            .checkEmailWebBannerLine1,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: const Color(
                                                              0xFF065F46),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      RichText(
                                                        text: TextSpan(
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12.5,
                                                            color: const Color(
                                                                0xFF047857),
                                                            height: 1.4,
                                                          ),
                                                          children: [
                                                            TextSpan(
                                                                text:
                                                                    'Check '),
                                                            TextSpan(
                                                              text: widget.email,
                                                              style: GoogleFonts
                                                                  .inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            const TextSpan(
                                                              text:
                                                                  ' — the link works once and expires in 60 minutes.',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 28),

                                          // ── Title ──────────────────────
                                          Text(
                                            AppConstants.checkEmailWebRightTitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppConstants
                                                .checkEmailWebRightSubtitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: const Color(0xFF64748B),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 28),

                                          // ── Resend countdown ───────────
                                          Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _secondsLeft > 0
                                                    ? const Color(0xFFE2E8F0)
                                                    : AppColors.webLoginButton,
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                onTap: _secondsLeft == 0
                                                    ? _startTimer
                                                    : null,
                                                child: Center(
                                                  child: _secondsLeft > 0
                                                      ? RichText(
                                                          text: TextSpan(
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 14,
                                                              color: const Color(
                                                                  0xFF94A3B8),
                                                            ),
                                                            children: [
                                                              TextSpan(
                                                                text: AppConstants
                                                                    .checkEmailWebResendPrefix,
                                                              ),
                                                              TextSpan(
                                                                text: _formatTime(
                                                                    _secondsLeft),
                                                                style: GoogleFonts
                                                                    .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: AppColors
                                                                      .webLoginButton,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : Text(
                                                          'Resend link',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .webLoginButton,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // ── Back to sign in ────────────
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed: widget.onBackToSignIn,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.webLoginButton,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                              ),
                                              child: Text(
                                                AppConstants
                                                    .checkEmailWebBackButton,
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // ── Wrong address ──────────────
                                          Center(
                                            child: GestureDetector(
                                              onTap:
                                                  widget.onUseDifferentEmail,
                                              child: RichText(
                                                text: TextSpan(
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color:
                                                        const Color(0xFF64748B),
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: AppConstants
                                                          .checkEmailWebWrongAddress,
                                                    ),
                                                    TextSpan(
                                                      text: AppConstants
                                                          .checkEmailWebUseDifferent,
                                                      style: GoogleFonts.inter(
                                                        color: AppColors
                                                            .webLoginButton,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
