import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

/// Signup-specific web HR registration screen.
class CandidateRegisterScreenWeb extends StatelessWidget {
  final bool isLoading;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final FocusNode firstNameFocus;
  final FocusNode lastNameFocus;
  final FocusNode emailFocus;
  final FocusNode phoneFocus;
  final FocusNode passwordFocus;
  final FocusNode confirmFocus;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onObscureToggle;
  final VoidCallback onObscureConfirmToggle;
  final VoidCallback onRegister;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onLoginTap;

  const CandidateRegisterScreenWeb({
    super.key,
    required this.isLoading,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmController,
    required this.firstNameFocus,
    required this.lastNameFocus,
    required this.emailFocus,
    required this.phoneFocus,
    required this.passwordFocus,
    required this.confirmFocus,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onObscureToggle,
    required this.onObscureConfirmToggle,
    required this.onRegister,
    required this.onGoogleSignIn,
    required this.onLoginTap,
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

                                    // Fixed gap — logo to headline block (max 72px)
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
                                                AppConstants
                                                    .candidateRegisterEyebrow,
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

                                        // Headline — "Your workspace, in one minute."
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: Responsive
                                                .leftPanelContentMaxWidth,
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: GoogleFonts.fraunces(
                                                color: Colors.white,
                                                fontSize:
                                                    Responsive.getFontSize(
                                                      context,
                                                      mobile: 32,
                                                      tablet: 36,
                                                      desktop: 42,
                                                    ),
                                                fontWeight: FontWeight.w600,
                                                height: 1.18,
                                                letterSpacing: -0.01,
                                              ),
                                              children: [
                                                const TextSpan(
                                                  text: 'Your workspace,\nin ',
                                                ),
                                                WidgetSpan(
                                                  child: ShaderMask(
                                                    blendMode: BlendMode.srcIn,
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          colors: [
                                                            AppColors
                                                                .webHeadlineFairlyStart,
                                                            AppColors
                                                                .webHeadlineFairlyEnd,
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ).createShader(bounds),
                                                    child: Text(
                                                      'one minute.',
                                                      style: GoogleFonts.fraunces(
                                                        fontSize:
                                                            Responsive.getFontSize(
                                                              context,
                                                              mobile: 32,
                                                              tablet: 36,
                                                              desktop: 42,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        height: 1.18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 22),

                                        // Subcopy
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: Responsive
                                                .leftPanelContentMaxWidth,
                                          ),
                                          child: Text(
                                            AppConstants
                                                .candidateRegisterLeftBody,
                                            style: GoogleFonts.inter(
                                              color: AppColors.webSubcopy,
                                              fontSize: 15.5,
                                              height: 1.75,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),

                                        // Bullet points
                                        _BulletPoint(
                                          text: AppConstants
                                              .candidateRegisterPoint1,
                                        ),
                                        const SizedBox(height: 16),
                                        _BulletPoint(
                                          text: AppConstants
                                              .candidateRegisterPoint2,
                                        ),
                                        const SizedBox(height: 16),
                                        _BulletPoint(
                                          text: AppConstants
                                              .candidateRegisterPoint3,
                                        ),
                                      ],
                                    ),

                                    // Push footer to bottom
                                    const SizedBox(height: 60),

                                    // Footer
                                    Text(
                                      '© 2026 SkillSense AI · Bahria University',
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
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: verticalPadding,
                                      horizontal: horizontalPadding,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: Responsive
                                            .rightPanelContentMaxWidth,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 80),
                                          // Title
                                          Text(
                                            AppConstants
                                                .candidateRegisterRightTitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Subtitle
                                          Text(
                                            AppConstants
                                                .hrRegisterRightSubtitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF64748B),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Google Button
                                          _GoogleSignInButton(
                                            onTap: onGoogleSignIn,
                                          ),
                                          const SizedBox(height: 16),

                                          // Divider
                                          const _WorkEmailDivider(),
                                          const SizedBox(height: 16),

                                          // Form Fields
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const _FormFieldLabel(
                                                      label: 'First name',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    _CustomTextField(
                                                      controller:
                                                          firstNameController,
                                                      focusNode: firstNameFocus,
                                                      hintText: 'e.g. Sara',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const _FormFieldLabel(
                                                      label: 'Last name',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    _CustomTextField(
                                                      controller:
                                                          lastNameController,
                                                      focusNode: lastNameFocus,
                                                      hintText: 'e.g. Khan',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          const _FormFieldLabel(
                                            label: 'Email Address',
                                          ),
                                          const SizedBox(height: 8),
                                          _CustomTextField(
                                            controller: emailController,
                                            focusNode: emailFocus,
                                            hintText: 'you@example.com',
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                          const SizedBox(height: 14),

                                          const _FormFieldLabel(
                                            label: 'Phone Number',
                                          ),
                                          const SizedBox(height: 8),
                                          _CustomTextField(
                                            controller: phoneController,
                                            focusNode: phoneFocus,
                                            hintText: '3XX XXX XXXX',
                                            keyboardType: TextInputType.phone,
                                          ),
                                          const SizedBox(height: 14),

                                          const _FormFieldLabel(
                                            label: 'Password',
                                          ),
                                          const SizedBox(height: 8),
                                          _CustomTextField(
                                            controller: passwordController,
                                            focusNode: passwordFocus,
                                            hintText: 'Min. 8 characters',
                                            obscureText: obscurePassword,
                                            suffixIcon: GestureDetector(
                                              onTap: onObscureToggle,
                                              child: Icon(
                                                obscurePassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: const Color(0xFF94A3B8),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          const _FormFieldLabel(
                                            label: 'Confirm Password',
                                          ),
                                          const SizedBox(height: 8),
                                          _CustomTextField(
                                            controller: confirmController,
                                            focusNode: confirmFocus,
                                            hintText: 'Re-enter your password',
                                            obscureText: obscureConfirm,
                                            suffixIcon: GestureDetector(
                                              onTap: onObscureConfirmToggle,
                                              child: Icon(
                                                obscureConfirm
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: const Color(0xFF94A3B8),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // Submit Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed: isLoading
                                                  ? null
                                                  : onRegister,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.candidatePrimary,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    AppColors.candidatePrimary
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
                                                      AppConstants
                                                          .hrRegisterCtaText,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Bottom Agreement Text
                                          Center(
                                            child: Text(
                                              AppConstants
                                                  .candidateRegisterAgreement,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: const Color(0xFF64748B),
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Already have an account? Sign in
                                          Center(
                                            child: GestureDetector(
                                              onTap: onLoginTap,
                                              child: RichText(
                                                text: TextSpan(
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: const Color(
                                                      0xFF64748B,
                                                    ),
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: AppConstants
                                                          .alreadyAccountPrompt,
                                                    ),
                                                    TextSpan(
                                                      text: AppConstants
                                                          .loginLinkText,
                                                      style: GoogleFonts.inter(
                                                        color: AppColors
                                                            .candidatePrimary,
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

// ── Supporting UI components ───────────────────────────────────────────────

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.candidatePrimary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF81A4FF), size: 13),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFE1E4F5),
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/google.svg', height: 18),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkEmailDivider extends StatelessWidget {
  const _WorkEmailDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or with work email',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
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
                  color: AppColors.candidatePrimary.withValues(alpha: 0.12),
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
              color: AppColors.candidatePrimary,
              width: 1.5,
            ),
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
