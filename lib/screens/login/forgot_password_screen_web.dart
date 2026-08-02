import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/web_auth_left_panel.dart';

class ForgotPasswordScreenWeb extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String email) onSend;

  const ForgotPasswordScreenWeb({
    super.key,
    required this.onBack,
    required this.onSend,
  });

  @override
  State<ForgotPasswordScreenWeb> createState() =>
      _ForgotPasswordScreenWebState();
}

class _ForgotPasswordScreenWebState extends State<ForgotPasswordScreenWeb> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSend(email);
      }
    });
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
                    // ── BACKGROUND ─────────────────────────────────────────
                    const Positioned.fill(child: WebAuthBackground()),

                    // ── CONTENT ────────────────────────────────────────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.webLayoutMaxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // LEFT PANEL (shared widget)
                            WebAuthLeftPanel(
                              eyebrow: AppConstants.forgotWebEyebrow,
                              headline: AppConstants.forgotWebHeadline,
                              body: AppConstants.forgotWebBody,
                              point1: AppConstants.forgotWebPoint1,
                              point2: AppConstants.forgotWebPoint2,
                              point3: AppConstants.forgotWebPoint3,
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
                                          Text(
                                            AppConstants.forgotWebRightTitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppConstants.forgotWebRightSubtitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF64748B),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 32),

                                          // Email field
                                          WebAuthFieldLabel(
                                            label: AppConstants
                                                .forgotWebEmailLabel,
                                          ),
                                          const SizedBox(height: 8),
                                          WebAuthTextField(
                                            controller: _emailController,
                                            focusNode: _emailFocus,
                                            hintText:
                                                AppConstants.forgotWebEmailHint,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                          const SizedBox(height: 28),

                                          // Send button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed:
                                                  _isLoading ? null : _submit,
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
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(
                                                      AppConstants.forgotWebButton,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // Back link
                                          Center(
                                            child: GestureDetector(
                                              onTap: widget.onBack,
                                              child: RichText(
                                                text: TextSpan(
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: const Color(
                                                        0xFF64748B),
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: AppConstants
                                                          .forgotWebRemembered,
                                                    ),
                                                    TextSpan(
                                                      text: AppConstants
                                                          .forgotWebBackLink,
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
