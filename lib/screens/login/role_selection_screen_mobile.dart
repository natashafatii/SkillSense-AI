import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

class RoleSelectionScreenMobile extends StatelessWidget {
  final String? selectedRole;
  final Function(String) onRoleSelected;
  final VoidCallback onContinue;
  final VoidCallback onSignUpTap;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const RoleSelectionScreenMobile({
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = Responsive.getSpacing(
            context,
            mobile: 24,
            tablet: 40,
          );

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- HERO HEADER ---
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.mobileHeaderBgStart,
                              AppColors.mobileHeaderBgEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 40,
                            ),
                            child: Column(
                              children: [
                                // Logo + Wordmark
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/images/logo.svg',
                                      height: 28,
                                      width: 28,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'SkillSense AI',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.01,
                                      ),
                                    ),
                                    // Balance the logo width to center the text perfectly
                                    const SizedBox(
                                      width: 38,
                                    ), // 28 (logo width) + 10 (gap)
                                  ],
                                ),
                                const SizedBox(height: 32),
                                // Eyebrow
                                Text(
                                  AppConstants.roleEyebrow,
                                  style: GoogleFonts.inter(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Headline
                                Text(
                                  AppConstants.roleTitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppColors.hrTextDark,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Subcopy
                                Text(
                                  AppConstants.roleSubtitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppColors.hrTextGrey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- WHITE BODY SECTION ---
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 32),
                                Text(
                                  AppConstants.selectRoleLabel,
                                  style: GoogleFonts.inter(
                                    color: AppColors.hrTextLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _MobileRoleCard(
                                  title: AppConstants.recruiterTitle,
                                  description:
                                      AppConstants.recruiterDescription,
                                  icon: Icons.work_outline_rounded,
                                  isSelected: selectedRole == 'recruiter',
                                  isHr: true,
                                  onTap: () => onRoleSelected('recruiter'),
                                ),
                                const SizedBox(height: 16),
                                _MobileRoleCard(
                                  title: AppConstants.jobSeekerTitle,
                                  description:
                                      AppConstants.jobSeekerDescription,
                                  icon: Icons.track_changes_rounded,
                                  isSelected: selectedRole == 'job_seeker',
                                  isHr: false,
                                  onTap: () => onRoleSelected('job_seeker'),
                                ),
                                const SizedBox(height: 24),
                                // Info Box
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.mobileInfoBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          AppConstants.roleHelperText,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.hrTextGrey,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- BOTTOM SECTION ---
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          24,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  color: selectedRole == 'recruiter'
                                      ? AppColors.webRoleHr
                                      : selectedRole == 'job_seeker'
                                      ? AppColors.webRoleCandidate
                                      : AppColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: selectedRole != null
                                        ? onContinue
                                        : null,
                                    child: Center(
                                      child: Text(
                                        selectedRole == 'recruiter'
                                            ? AppConstants.continueAsRecruiter
                                            : AppConstants.continueAsCandidate,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: onSignUpTap,
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                    color: AppColors.hrTextGrey,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: "${AppConstants.noAccount} ",
                                    ),
                                    TextSpan(
                                      text: AppConstants.signUp,
                                      style: GoogleFonts.inter(
                                        color:
                                            AppColors.mobileButtonGradientStart,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Add a small safe area at the very bottom
                            SafeArea(
                              top: false,
                              child: const SizedBox(height: 8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileRoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final bool isHr;
  final VoidCallback onTap;

  const _MobileRoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.isHr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg = isHr
        ? AppColors.mobileIconBgHr
        : AppColors.mobileIconBgCandidate;
    final Color iconColor = isHr
        ? AppColors.mobileIconHr
        : AppColors.mobileIconCandidate;
    final Color borderColor = isSelected
        ? AppColors.mobileIconHr
        : AppColors.webCardBorderUnselected;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.mobileIconHr.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Tile
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hrTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.hrTextGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Radio Button
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.mobileIconHr
                      : AppColors.webCardBorderUnselected,
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
