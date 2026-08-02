import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

class LoginScreenWeb extends StatelessWidget {
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool rememberMe;
  final String? errorMessage;
  final VoidCallback onObscureToggle;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;

  const LoginScreenWeb({
    super.key,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.rememberMe,
    this.errorMessage,
    required this.onObscureToggle,
    required this.onRememberMeChanged,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onCreateAccount,
  });

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
          final double verticalPadding = constraints.maxHeight * 0.05;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // ── BACKGROUND LAYER ─────────────────────────────────
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: dark gradient with a subtle grid background
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(-0.5, -0.866),
                                      end: Alignment(0.5, 0.866),
                                      stops: [0.0, 0.55, 1.0],
                                      colors: [
                                        AppColors.webPanelGradientStart,
                                        AppColors.webPanelGradientMid,
                                        AppColors.webPanelGradientEnd,
                                      ],
                                    ),
                                  ),
                                ),
                                // Soft radial glow top-right
                                Positioned(
                                  top: -300,
                                  right: -300,
                                  child: Container(
                                    width: 800,
                                    height: 800,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.webGlow,
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.8],
                                      ),
                                    ),
                                  ),
                                ),
                                // Hairline right edge
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 1,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.webHairline,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right: pure white
                          Expanded(child: Container(color: Colors.white)),
                        ],
                      ),
                    ),

                    // ── CONTENT LAYER ─────────────────────────────────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.webLayoutMaxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── LEFT PANEL ────────────────────────────────
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: verticalPadding,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Brand row
                                    Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/logo.svg',
                                          height: 36,
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'SkillSense AI',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.01,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Fixed gap — logo to headline block
                                    SizedBox(
                                      height: verticalPadding.clamp(40, 72),
                                    ),

                                    // Headline block
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Eyebrow
                                        Row(
                                          children: [
                                            Container(
                                              width: 18,
                                              height: 1,
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                AppConstants.loginWebEyebrow,
                                                style: GoogleFonts.inter(
                                                  color: AppColors.webEyebrow,
                                                  fontSize:
                                                      Responsive.getFontSize(
                                                    context,
                                                    mobile: 10,
                                                    desktop: 11.5,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 22),

                                        // Headline — "Everything is where you left it."
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: Responsive
                                                .leftPanelContentMaxWidth,
                                          ),
                                          child: _buildFormattedHeadline(context),
                                        ),
                                        const SizedBox(height: 22),

                                        // Subcopy
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: Responsive
                                                .leftPanelContentMaxWidth,
                                          ),
                                          child: Text(
                                            AppConstants.loginWebBody,
                                            style: GoogleFonts.inter(
                                              color: AppColors.webSubcopy,
                                              fontSize: 15.5,
                                              height: 1.75,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 38),

                                        // Bullet points
                                        Column(
                                          children: [
                                            _WebFeatureItem(
                                              text: AppConstants.loginWebPoint1,
                                            ),
                                            const SizedBox(height: 16),
                                            _WebFeatureItem(
                                              text: AppConstants.loginWebPoint2,
                                            ),
                                            const SizedBox(height: 16),
                                            _WebFeatureItem(
                                              text: AppConstants.loginWebPoint3,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Push footer to bottom
                                    const SizedBox(height: 60),

                                    // Footer
                                    Text(
                                      '© 2026 SkillSense AI · Bahria University Lahore',
                                      style: GoogleFonts.inter(
                                        color: AppColors.webFooterText,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ── RIGHT PANEL ───────────────────────────────
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
                                        maxWidth: Responsive
                                            .rightPanelContentMaxWidth,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          Text(
                                            AppConstants.loginWebRightTitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Subtitle
                                          Text(
                                            AppConstants.loginWebRightSubtitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF64748B),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 32),

                                          // Error banner (shown on bad credentials)
                                          if (errorMessage != null) ...
                                            [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF2F2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(0xFFFCA5A5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.close,
                                                      color: Color(0xFFEF4444),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            AppConstants
                                                                .loginWebErrorTitle,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: const Color(
                                                                  0xFF991B1B),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Text(
                                                            AppConstants
                                                                .loginWebErrorBody,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 12.5,
                                                              color: const Color(
                                                                  0xFFB91C1C),
                                                              height: 1.4,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                            ],

                                          // Form Fields
                                          const _FormFieldLabel(label: 'Email'),
                                          const SizedBox(height: 8),
                                          _CustomTextField(
                                            controller: emailController,
                                            focusNode: emailFocus,
                                            hintText: 'you@company.com',
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                          const SizedBox(height: 20),

                                          const _FormFieldLabel(label: 'Password'),
                                          const SizedBox(height: 8),
                                          _CustomTextField(
                                            controller: passwordController,
                                            focusNode: passwordFocus,
                                            hintText: '••••••••',
                                            obscureText: obscurePassword,
                                            suffixIcon: GestureDetector(
                                              onTap: onObscureToggle,
                                              child: Center(
                                                widthFactor: 1.0,
                                                heightFactor: 1.0,
                                                child: Text(
                                                  obscurePassword ? 'Show' : 'Hide',
                                                  style: GoogleFonts.inter(
                                                    color: AppColors.webLoginButton,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // Keep me signed in & Forgot Password
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: Checkbox(
                                                      value: rememberMe,
                                                      onChanged: onRememberMeChanged,
                                                      activeColor: AppColors.webLoginButton,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(4),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    AppConstants.loginWebKeepMeSignedIn,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      color: const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              GestureDetector(
                                                onTap: onForgotPassword,
                                                child: Text(
                                                  AppConstants.loginWebForgotPassword,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.webLoginButton,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 32),

                                          // Submit Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed: isLoading ? null : onLogin,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.webLoginButton,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: AppColors
                                                    .webLoginButton
                                                    .withValues(alpha: 0.5),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                              ),
                                              child: isLoading
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
                                                      AppConstants.loginWebButton,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 24),

                                          // Don't have an account? Sign Up
                                          Center(
                                            child: GestureDetector(
                                              onTap: onCreateAccount,
                                              child: RichText(
                                                text: TextSpan(
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: const Color(
                                                      0xFF64748B,
                                                    ),
                                                  ),
                                                  children: [
                                                    const TextSpan(
                                                      text: AppConstants
                                                          .loginWebNewUserPrompt,
                                                    ),
                                                    TextSpan(
                                                      text: AppConstants
                                                          .loginWebCreateAccountLink,
                                                      style: GoogleFonts.inter(
                                                        color:
                                                            AppColors.webLoginButton,
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

  Widget _buildFormattedHeadline(BuildContext context) {
    final double fontSize = Responsive.getFontSize(
      context,
      mobile: 32,
      tablet: 36,
      desktop: 42,
    );
    return RichText(
      text: TextSpan(
        style: GoogleFonts.fraunces(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.18,
          letterSpacing: -0.01,
        ),
        children: [
          const TextSpan(
            text: 'Everything is where\nyou ',
          ),
          WidgetSpan(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  AppColors.webHeadlineFairlyStart,
                  AppColors.webHeadlineFairlyEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'left it.',
                style: GoogleFonts.fraunces(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebFeatureItem extends StatelessWidget {
  final String text;

  const _WebFeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.webCheckTileGradientStart,
                AppColors.webCheckTileGradientEnd,
              ],
            ),
            border: Border.all(color: AppColors.webCheckTileBorder, width: 1),
          ),
          child: const Center(
            child: Icon(Icons.check, size: 14, color: AppColors.webCheckIcon),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: AppColors.webCheckText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormFieldLabel extends StatelessWidget {
  final String label;

  const _FormFieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const _CustomTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: AppColors.webLoginButton.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: AppColors.webLoginButton,
              width: 1.5,
            ),
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
