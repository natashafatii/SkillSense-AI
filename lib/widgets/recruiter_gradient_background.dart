import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Soft blue background used by Recruiter workspace screens.
class RecruiterGradientBackground extends StatelessWidget {
  const RecruiterGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkTheme;
    final fadeColor = context
        .themeSurface(AppColors.backgroundBase)
        .withValues(alpha: 0);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: dark
          ? MediaQuery.sizeOf(context).height
          : MediaQuery.sizeOf(context).height * 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF1A2A43), Color(0xFF111827)]
                : [Color(0xFFDCEBFC), Color(0xFFF1F6FD), fadeColor],
            stops: dark ? null : const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}
