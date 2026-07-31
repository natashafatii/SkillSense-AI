import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import '../login/role_selection_screen.dart';
import '../signup/signup_role_selection_screen.dart';

/// Web-only welcome screen: dark left panel with grid overlay + white right panel.
class WelcomeScreenWeb extends StatelessWidget {
  const WelcomeScreenWeb({super.key});

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

          // Split headline by 'skill' to apply gradient highlight while keeping it centered on the constant
          final List<String> headlineParts = AppConstants.welcomeWebHeadline.split('skill');
          final String beforeSkill = headlineParts.isNotEmpty ? headlineParts[0] : 'Interviews that\nreveal ';
          final String afterSkill = headlineParts.length > 1 ? headlineParts[1] : ', not\nscript.';

          return Stack(
            children: [
              // ── BACKGROUND LAYER ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: dark gradient panel with grid overlay
                  Expanded(
                    child: Stack(
                      children: [
                        // Base background gradient
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
                        // 1px hairline on the right edge
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

              // ── CONTENT LAYER ─────────────────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.webLayoutMaxWidth,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── LEFT PANEL ─────────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  Text(
                                    'SkillSense AI',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.01,
                                    ),
                                  ),
                                ],
                              ),

                              // Headline block
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Eyebrow with extending line indicator
                                  Row(
                                    children: [
                                      Text(
                                        AppConstants.welcomeWebEyebrow,
                                        style: GoogleFonts.inter(
                                          color: AppColors.webEyebrow,
                                          fontSize: Responsive.getFontSize(
                                            context,
                                            mobile: 10,
                                            desktop: 11.5,
                                          ),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: Colors.white.withValues(alpha: 0.12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),

                                  // Main headline — Inter font matching screenshot
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: Responsive.leftPanelContentMaxWidth,
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: Responsive.getFontSize(
                                            context,
                                            mobile: 30,
                                            tablet: 34,
                                            desktop: 42,
                                          ),
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                          letterSpacing: -1.0,
                                        ),
                                        children: [
                                          TextSpan(text: beforeSkill),
                                          WidgetSpan(
                                            child: ShaderMask(
                                              blendMode: BlendMode.srcIn,
                                              shaderCallback: (bounds) => const LinearGradient(
                                                colors: [
                                                  Color(0xFF7190E2), // Left end: indigo-blue
                                                  Color(0xFF3AB5B7), // Right end: cyan-teal
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                              child: Text(
                                                'skill',
                                                style: GoogleFonts.inter(
                                                  fontSize: Responsive.getFontSize(
                                                    context,
                                                    mobile: 30,
                                                    tablet: 34,
                                                    desktop: 42,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TextSpan(text: afterSkill),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),

                                  // Body subcopy
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: Responsive.leftPanelContentMaxWidth,
                                    ),
                                    child: Text(
                                      AppConstants.welcomeWebBody,
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
                                    text: AppConstants.welcomeWebPoint1,
                                  ),
                                  const SizedBox(height: 16),
                                  _BulletPoint(
                                    text: AppConstants.welcomeWebPoint2,
                                  ),
                                  const SizedBox(height: 16),
                                  _BulletPoint(
                                    text: AppConstants.welcomeWebPoint3,
                                  ),
                                ],
                              ),

                              // Footer
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '© 2026 SKILLSENSE AI',
                                    style: GoogleFonts.inter(
                                      color: AppColors.webFooterText,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'BAHRIA UNIVERSITY LAHORE',
                                    style: GoogleFonts.inter(
                                      color: AppColors.webFooterText,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── RIGHT PANEL ────────────────────────────────────────
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: verticalPadding,
                              horizontal: horizontalPadding,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 450.0, // Match screenshot layout width perfectly
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    AppConstants.welcomeWebRightTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Subtitle
                                  Text(
                                    AppConstants.welcomeWebRightSubtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF64748B),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Create an account button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOut,
                                      decoration: BoxDecoration(
                                        color: AppColors.webRoleHr,
                                        borderRadius: BorderRadius.circular(26), // Pill shape
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.webRoleHr.withValues(alpha: 0.30),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(26),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const SignupRoleSelectionScreen(),
                                              ),
                                            );
                                          },
                                          child: Center(
                                            child: Text(
                                              AppConstants.welcomeWebCreateAccount,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Agreement text
                                  Center(
                                    child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: const Color(0xFF64748B),
                                          height: 1.5,
                                        ),
                                        children: [
                                          const TextSpan(text: 'By continuing you agree to the '),
                                          TextSpan(
                                            text: 'Terms',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF64748B),
                                              decoration: TextDecoration.underline,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF64748B),
                                              decoration: TextDecoration.underline,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const TextSpan(text: '.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Divider Line
                                  Container(
                                    height: 1,
                                    color: const Color(0xFFEFF3F8),
                                    margin: const EdgeInsets.symmetric(vertical: 16),
                                  ),

                                  // Already have an account? Log in
                                  Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RoleSelectionScreen(),
                                          ),
                                        );
                                      },
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: const Color(0xFF64748B),
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '${AppConstants.welcomeWebHaveAccount} ',
                                            ),
                                            TextSpan(
                                              text: AppConstants.welcomeWebLoginLink.trim(),
                                              style: GoogleFonts.inter(
                                                color: AppColors.webRoleHr,
                                                fontWeight: FontWeight.w600,
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
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Reusable bullet point widget ───────────────────────────────────────────────
class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.check,
              color: Colors.white,
              size: 11,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFFE2E8F0),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
