import 'package:flutter/material.dart';
import 'recruiter_button_style.dart';
import '../constants/app_colors.dart';

/// Active pre-auth CTAs share recruiter blue; disabled styles remain local.
class PreAuthButtonStyle {
  static const blue = RecruiterButtonStyle.blue;
  static Color roleColor(String? role) =>
      role == 'job_seeker' ? AppColors.webRoleCandidate : blue;

  static List<BoxShadow> roleGlow(String? role) => [
    BoxShadow(
      color: roleColor(role).withValues(alpha: .24),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
  static final glow = <BoxShadow>[
    BoxShadow(
      color: blue.withValues(alpha: .24),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static ButtonStyle active(ButtonStyle base) =>
      RecruiterButtonStyle.primary(base).copyWith(
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? base.elevation?.resolve(states)
              : 3,
        ),
        shadowColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? base.shadowColor?.resolve(states)
              : blue.withValues(alpha: .24),
        ),
      );
}
