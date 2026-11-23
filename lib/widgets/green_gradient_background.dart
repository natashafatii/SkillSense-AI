import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'candidate_button_style.dart';

/// A reusable green gradient background for candidate/job seeker screens.
class GreenGradientBackground extends StatelessWidget {
  const GreenGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkTheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: dark
          ? MediaQuery.sizeOf(context).height
          : MediaQuery.of(context).size.height * 0.5,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF1A2A43), Color(0xFF111827)]
                : [
                    Color.alphaBlend(
                      CandidateButtonStyle.deepTeal.withValues(alpha: .14),
                      Colors.white,
                    ),
                    Color.alphaBlend(
                      CandidateButtonStyle.deepTeal.withValues(alpha: .04),
                      Colors.white,
                    ).withValues(alpha: .5),
                    context
                        .themeSurface(AppColors.backgroundBase)
                        .withValues(alpha: 0.0),
                  ],
            stops: dark ? null : const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}
