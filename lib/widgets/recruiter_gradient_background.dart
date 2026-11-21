import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Soft blue background used by Recruiter workspace screens.
class RecruiterGradientBackground extends StatelessWidget {
  const RecruiterGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final fadeColor = context
        .themeSurface(AppColors.backgroundBase)
        .withValues(alpha: 0);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDCEBFC), Color(0xFFF1F6FD), fadeColor],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}
