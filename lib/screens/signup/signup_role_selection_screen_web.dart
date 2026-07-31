import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

/// Signup-specific web role selection screen.
/// Left panel: dark gradient with new "Get the right experience" headline.
/// Right panel: light lavender bg, "I'm a..." title, filled role cards on selection.
class SignupRoleSelectionScreenWeb extends StatelessWidget {
  final String? selectedRole;
  final Function(String) onRoleSelected;
  final VoidCallback onContinue;
  final VoidCallback onLoginTap;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const SignupRoleSelectionScreenWeb({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
    required this.onContinue,
    required this.onLoginTap,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRecruiter = selectedRole == 'recruiter';
    final bool isJobSeeker = selectedRole == 'job_seeker';

    final Color ctaColor = isRecruiter
        ? AppColors.webRoleHr
        : (isJobSeeker
            ? AppColors.webRoleCandidate
            : AppColors.primary.withValues(alpha: 0.4));

    final String ctaText = isRecruiter
        ? AppConstants.continueAsRecruiter
        : (isJobSeeker
            ? AppConstants.continueAsCandidate
            : 'Continue');

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
                          // Left: dark gradient
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
                          // Right: light lavender
                          Expanded(
                            child: Container(
                              color: const Color(0xFFF5F7FF),
                            ),
                          ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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

                                    SizedBox(height: verticalPadding),

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
                                                AppConstants.roleEyebrow,
                                                style: GoogleFonts.inter(
                                                  color: AppColors.webEyebrow,
                                                  fontSize: Responsive
                                                      .getFontSize(
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

                                        // Headline — "Get the right experience from the start."
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth:
                                                Responsive.leftPanelContentMaxWidth,
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: GoogleFonts.fraunces(
                                                color: Colors.white,
                                                fontSize: Responsive.getFontSize(
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
                                                  text: 'Get the ',
                                                ),
                                                WidgetSpan(
                                                  child: ShaderMask(
                                                    blendMode: BlendMode.srcIn,
                                                    shaderCallback:
                                                        (bounds) =>
                                                            const LinearGradient(
                                                              colors: [
                                                                AppColors
                                                                    .webHeadlineFairlyStart,
                                                                AppColors
                                                                    .webHeadlineFairlyEnd,
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ).createShader(
                                                              bounds,
                                                            ),
                                                    child: Text(
                                                      'right',
                                                      style:
                                                          GoogleFonts.fraunces(
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
                                                const TextSpan(
                                                  text:
                                                      ' experience\nfrom the start.',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 22),

                                        // Subcopy
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth:
                                                Responsive.leftPanelContentMaxWidth,
                                          ),
                                          child: Text(
                                            AppConstants.signupWebLeftBody,
                                            style: GoogleFonts.inter(
                                              color: AppColors.webSubcopy,
                                              fontSize: Responsive.getFontSize(
                                                context,
                                                mobile: 14,
                                                desktop: 15.5,
                                              ),
                                              height: 1.75,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

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
                                        maxWidth: 450.0,
                                      ),
                                      child: FadeTransition(
                                        opacity: fadeAnimation,
                                        child: SlideTransition(
                                          position: slideAnimation,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Title
                                              Text(
                                                AppConstants.signupWebTitle,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                  fontSize:
                                                      Responsive.getFontSize(
                                                    context,
                                                    mobile: 26,
                                                    tablet: 28,
                                                    desktop: 32,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 12),

                                              // Subtitle
                                              Text(
                                                AppConstants.signupWebSubtitle,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                  fontSize:
                                                      Responsive.getFontSize(
                                                    context,
                                                    mobile: 14,
                                                    desktop: 15,
                                                  ),
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                      const Color(0xFF64748B),
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 32),

                                              // Recruiter / HR card
                                              _SignupRoleCard(
                                                title: AppConstants
                                                    .signupRecruiterTitle,
                                                description: AppConstants
                                                    .signupRecruiterDescription,
                                                icon:
                                                    Icons.work_outline_rounded,
                                                roleColor: AppColors.webRoleHr,
                                                isSelected: isRecruiter,
                                                onTap: () =>
                                                    onRoleSelected('recruiter'),
                                              ),
                                              const SizedBox(height: 16),

                                              // Job Seeker card
                                              _SignupRoleCard(
                                                title: AppConstants
                                                    .signupJobSeekerTitle,
                                                description: AppConstants
                                                    .signupJobSeekerDescription,
                                                icon:
                                                    Icons.person_outline_rounded,
                                                roleColor:
                                                    AppColors.webRoleCandidate,
                                                isSelected: isJobSeeker,
                                                onTap: () => onRoleSelected(
                                                  'job_seeker',
                                                ),
                                              ),
                                              const SizedBox(height: 24),

                                              // Helper text
                                              Text(
                                                AppConstants.signupWebHelperText,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color:
                                                      const Color(0xFF64748B),
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 32),

                                              // Continue button
                                              SizedBox(
                                                width: double.infinity,
                                                height: 56,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 250,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  decoration: BoxDecoration(
                                                    color: ctaColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      28,
                                                    ),
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        28,
                                                      ),
                                                      onTap: selectedRole !=
                                                              null
                                                          ? onContinue
                                                          : null,
                                                      child: Center(
                                                        child: Text(
                                                          ctaText,
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.white,
                                                            letterSpacing: 0,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 20),

                                              // Already have an account?
                                              GestureDetector(
                                                onTap: onLoginTap,
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
                                                            .alreadyAccountPrompt,
                                                      ),
                                                      TextSpan(
                                                        text: AppConstants
                                                            .loginLinkText,
                                                        style: GoogleFonts.inter(
                                                          color:
                                                              AppColors.webRoleHr,
                                                          fontWeight:
                                                              FontWeight.w600,
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

// ── Role card widget ──────────────────────────────────────────────────────────

class _SignupRoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color roleColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _SignupRoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.roleColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          // Filled with role colour when selected, white when not
          color: isSelected ? roleColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? roleColor : AppColors.webCardBorderUnselected,
            width: isSelected ? 0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: roleColor.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Icon tile
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.20)
                    : roleColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : roleColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFFCBD5E0),
                  width: isSelected ? 0 : 1.5,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
