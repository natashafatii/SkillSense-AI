import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A reusable gradient background that sits at the top half of the screen.
/// Used across Welcome, Login, and Role Selection screens.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

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
              AppColors.bgGradientTop,
              AppColors.bgGradientMid.withValues(alpha: 0.5),
              AppColors.backgroundBase.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}
