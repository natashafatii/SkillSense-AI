import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A reusable green gradient background for candidate/job seeker screens.
class GreenGradientBackground extends StatelessWidget {
  const GreenGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFC8F0D0), // Light vibrant green
              const Color(0xFFE8F5E9).withValues(alpha: 0.5),
              AppColors.backgroundBase.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}
