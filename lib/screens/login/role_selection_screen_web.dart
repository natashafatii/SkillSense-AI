import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

class RoleSelectionScreenWeb extends StatelessWidget {
  final String? selectedRole;
  final Function(String) onRoleSelected;
  final VoidCallback onContinue;
  final VoidCallback onSignUpTap;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const RoleSelectionScreenWeb({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
    required this.onContinue,
    required this.onSignUpTap,
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
        ? 'Continue as recruiter'
        : (isJobSeeker ? 'Continue as candidate' : 'Continue');

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive values
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
                    // --- BACKGROUND LAYER ---
                    // Spans the full width of the screen, regardless of the max-width content constraint.
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 1,
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
                                // 1px hairline on the left edge
                                Positioned(
                                  left: 0,
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
                          Expanded(
                            flex: 1,
                            child: Container(color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // --- CONTENT LAYER ---
                    // Capped at 1200px max width and centered on very wide screens.
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.webLayoutMaxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // LEFT PANEL CONTENT
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
                                    // Brand Row
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

                                    // Headline Block
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Eyebrow Label
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
                                                  fontSize: Responsive.getFontSize(context, mobile: 10, desktop: 11.5),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 22),
                                        // Headline
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth:
                                                Responsive.leftPanelContentMaxWidth,
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: GoogleFonts.fraunces(
                                                color: Colors.white,
                                                fontSize: Responsive.getFontSize(context, mobile: 32, tablet: 36, desktop: 42),
                                                fontWeight: FontWeight.w600,
                                                height: 1.18,
                                                letterSpacing: -0.01,
                                              ),
                                              children: [
                                                const TextSpan(
                                                  text:
                                                      'The same interview,\nseen ',
                                                ),
                                                WidgetSpan(
                                                  child: ShaderMask(
                                                    blendMode: BlendMode.srcIn,
                                                    shaderCallback:
                                                        (bounds) => const LinearGradient(
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
                                                        ).createShader(bounds),
                                                    child: Text(
                                                      'fairly',
                                                      style:
                                                          GoogleFonts.fraunces(
                                                        fontSize: Responsive.getFontSize(context, mobile: 32, tablet: 36, desktop: 42),
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
                                                  text: ' from both sides.',
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
                                            AppConstants.webLeftPanelBody,
                                            style: GoogleFonts.inter(
                                              color: AppColors.webSubcopy,
                                              fontSize: Responsive.getFontSize(context, mobile: 14, desktop: 15.5),
                                              height: 1.75,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 38),
                                        // Checklist
                                        Column(
                                          children: [
                                            _WebFeatureItem(
                                              text: AppConstants
                                                  .webLeftPanelPoint1,
                                            ),
                                            const SizedBox(height: 16),
                                            _WebFeatureItem(
                                              text: AppConstants
                                                  .webLeftPanelPoint2,
                                            ),
                                            const SizedBox(height: 16),
                                            _WebFeatureItem(
                                              text: AppConstants
                                                  .webLeftPanelPoint3,
                                            ),
                                          ],
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
                            
                            // RIGHT PANEL CONTENT
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
                                        maxWidth: 450.0, // Limit width to match screenshot exactly
                                      ),
                                      child: FadeTransition(
                                        opacity: fadeAnimation,
                                        child: SlideTransition(
                                          position: slideAnimation,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppConstants.roleTitle,
                                                style: GoogleFonts.inter(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0F172A),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                "Your role decides which workspace you get. You can change it later in settings.",
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w400,
                                                  color: const Color(0xFF64748B),
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 32),
                                              _WebRoleCard(
                                                title: AppConstants.recruiterTitle,
                                                description: AppConstants.recruiterDescription,
                                                icon: Icons.view_sidebar_outlined,
                                                roleColor: AppColors.webRoleHr,
                                                isSelected: isRecruiter,
                                                onTap:
                                                    () => onRoleSelected(
                                                      'recruiter',
                                                    ),
                                              ),
                                              const SizedBox(height: 16),
                                              _WebRoleCard(
                                                title: AppConstants.jobSeekerTitle,
                                                description: AppConstants.jobSeekerDescription,
                                                icon: Icons.track_changes, // Target/bullseye icon matching the screenshot
                                                roleColor:
                                                    AppColors.webRoleCandidate,
                                                isSelected: isJobSeeker,
                                                onTap:
                                                    () => onRoleSelected(
                                                      'job_seeker',
                                                    ),
                                              ),
                                              const SizedBox(height: 24),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(0xFFF1F5F9),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Padding(
                                                      padding: EdgeInsets.only(top: 2),
                                                      child: Icon(
                                                        Icons.info_outline,
                                                        size: 15,
                                                        color: Color(0xFF94A3B8),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        "One account can hold both roles — recruiters who also apply to jobs switch from the workspace menu.",
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: const Color(0xFF64748B),
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 32),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 52,
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 250),
                                                  curve: Curves.easeOut,
                                                  decoration: BoxDecoration(
                                                    color: ctaColor,
                                                    borderRadius: BorderRadius.circular(26), // Pilled rounded corners
                                                    boxShadow: selectedRole != null
                                                        ? [
                                                            BoxShadow(
                                                              color: ctaColor.withValues(alpha: 0.30),
                                                              blurRadius: 18,
                                                              offset: const Offset(0, 6),
                                                            ),
                                                          ]
                                                        : [],
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(26),
                                                      onTap: selectedRole != null ? onContinue : null,
                                                      child: Center(
                                                        child: Text(
                                                          ctaText,
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
                                              GestureDetector(
                                                onTap: onSignUpTap,
                                                child: Center(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: const Color(0xFF64748B),
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text: "${AppConstants.noAccount} ",
                                                        ),
                                                        TextSpan(
                                                          text: AppConstants.signUp,
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

class _WebRoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color roleColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _WebRoleCard({
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? roleColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: roleColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: roleColor.withValues(alpha: 0.18),
                  width: 1.0,
                ),
              ),
              child: Icon(
                icon,
                color: roleColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? roleColor : const Color(0xFFCBD5E1),
                  width: isSelected ? 2.0 : 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: roleColor,
                        ),
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
