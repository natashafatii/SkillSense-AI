import 'package:skillsense_ai/widgets/pre_auth_button_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';

/// Signup-only mobile presentation. The sign-in role selection widget is unchanged.
class SignupRoleSelectionScreenMobile extends StatelessWidget {
  const SignupRoleSelectionScreenMobile({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
    required this.onContinue,
    required this.onFlowToggle,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  final String? selectedRole;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onContinue;
  final VoidCallback onFlowToggle;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.getSpacing(
      context,
      mobile: 24,
      tablet: 40,
    );
    final background = isDark ? const Color(0xFF0C1220) : Colors.white;
    final text = isDark ? const Color(0xFFE7ECF6) : AppColors.hrTextDark;
    final secondary = isDark ? const Color(0xFF9FACC6) : AppColors.hrTextGrey;
    final muted = isDark ? const Color(0xFF7C89A6) : AppColors.hrTextLight;
    final card = isDark ? const Color(0xFF121A2C) : Colors.white;
    final edge = isDark
        ? const Color(0xFF2A3650)
        : AppColors.webCardBorderUnselected;
    final infoBackground = isDark
        ? const Color(0xFF172035)
        : AppColors.mobileInfoBg;

    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? const [Color(0xFF1A2246), Color(0xFF121A34)]
                            : const [
                                AppColors.mobileHeaderBgStart,
                                AppColors.mobileHeaderBgEnd,
                              ],
                      ),
                      borderRadius: const BorderRadius.only(
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
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Text(
                              AppConstants.roleEyebrow,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: AppColors.mobileIconHr,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Who are you creating an account as?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: text,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppConstants.roleSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: secondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _RoleCard(
                              title: 'Recruiter / HR',
                              description:
                                  'Post roles, screen candidates, run AI interviews.',
                              icon: Icons.work_outline_rounded,
                              iconBackground: AppColors.mobileIconBgHr,
                              iconColor: AppColors.mobileIconHr,
                              selected: selectedRole == 'recruiter',
                              cardColor: card,
                              textColor: text,
                              secondaryColor: secondary,
                              edgeColor: edge,
                              onTap: () => onRoleSelected('recruiter'),
                            ),
                            const SizedBox(height: 16),
                            _RoleCard(
                              title: 'Job Seeker',
                              description:
                                  'Apply, take AI interviews, get feedback.',
                              icon: Icons.track_changes_rounded,
                              iconBackground: AppColors.mobileIconBgCandidate,
                              iconColor: AppColors.mobileIconCandidate,
                              selectedBorderColor: AppColors.webRoleCandidate,
                              selected: selectedRole == 'job_seeker',
                              cardColor: card,
                              textColor: text,
                              secondaryColor: secondary,
                              edgeColor: edge,
                              onTap: () => onRoleSelected('job_seeker'),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: infoBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Your role determines which features you see. You can update this anytime in settings.',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: secondary,
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      24,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selectedRole == null
                                  ? AppColors.primary.withValues(alpha: .4)
                                  : PreAuthButtonStyle.roleColor(selectedRole),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: selectedRole == null
                                  ? null
                                  : PreAuthButtonStyle.roleGlow(selectedRole),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: selectedRole == null ? null : onContinue,
                                child: Center(
                                  child: Text(
                                    selectedRole == 'recruiter'
                                        ? AppConstants.continueAsRecruiter
                                        : selectedRole == 'job_seeker'
                                        ? AppConstants.continueAsCandidate
                                        : 'Continue',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: onFlowToggle,
                          child: Text.rich(
                            TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: secondary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Log in',
                                  style: const TextStyle(
                                    color: PreAuthButtonStyle.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SafeArea(top: false, child: const SizedBox(height: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.selected,
    required this.cardColor,
    required this.textColor,
    required this.secondaryColor,
    required this.edgeColor,
    required this.onTap,
    this.selectedBorderColor = AppColors.mobileIconHr,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconBackground,
      iconColor,
      cardColor,
      textColor,
      secondaryColor,
      edgeColor;
  final Color selectedBorderColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.mobileIconHr.withValues(alpha: .16)
                    : AppColors.mobileIconBgHr.withValues(alpha: .6))
              : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? selectedBorderColor : edgeColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.4,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? selectedBorderColor : edgeColor,
                  width: selected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
