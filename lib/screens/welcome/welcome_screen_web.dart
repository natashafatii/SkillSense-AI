import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

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
                                      fontWeight: FontWeight.w600,
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
                                        AppConstants.welcomeWebEyebrow.toUpperCase(),
                                        style: GoogleFonts.jetBrainsMono(
                                          color: const Color(0xFF7BA5FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.8,
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

                                  // Main headline
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
                                            mobile: 32,
                                            tablet: 36,
                                            desktop: 40,
                                          ),
                                          fontWeight: FontWeight.w700,
                                          height: 1.18,
                                          letterSpacing: -1.2,
                                        ),
                                        children: [
                                          TextSpan(text: beforeSkill),
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.baseline,
                                            baseline: TextBaseline.alphabetic,
                                            child: ShaderMask(
                                              blendMode: BlendMode.srcIn,
                                              shaderCallback: (bounds) => const LinearGradient(
                                                colors: [
                                                  AppColors.webHeadlineFairlyStart,
                                                  AppColors.webHeadlineFairlyEnd,
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ).createShader(bounds),
                                              child: Text(
                                                'skill',
                                                style: GoogleFonts.inter(
                                                  fontSize: Responsive.getFontSize(
                                                    context,
                                                    mobile: 32,
                                                    tablet: 36,
                                                    desktop: 40,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.18,
                                                  letterSpacing: -1.2,
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
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w400,
                                        height: 1.6,
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
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '© 2026 SkillSense AI',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
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
                                            Navigator.pushNamed(
                                              context,
                                              '/signup/role',
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


                                  // Divider Line
                                  Container(
                                    height: 1,
                                    color: const Color(0xFFEFF3F8),
                                    margin: const EdgeInsets.symmetric(vertical: 16),
                                  ),

                                  // Already have an account? Log in
                                  Center(
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/login/role',
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
              color: const Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
