import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import 'recruiter_mobile_nav.dart';
import 'recruiter_side_nav.dart';
import 'recruiter_button_style.dart';
import 'recruiter_gradient_background.dart';

/// Keeps one navigation surface around every recruiter route.
class RecruiterScaffold extends StatelessWidget {
  final String currentRoute;
  final Widget body;
  final String? selectedRoute;
  final bool glowSelected;
  const RecruiterScaffold({
    super.key,
    required this.currentRoute,
    required this.body,
    this.selectedRoute,
    this.glowSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final isProfile = currentRoute == '/recruiter/profile';
    final themedBody = RecruiterButtonTheme(child: body);
    if (isMobile) {
      return Scaffold(
        backgroundColor: context.themeCanvas(const Color(0xFFF8FAFC)),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [const RecruiterGradientBackground(), themedBody],
          ),
        ),
        bottomNavigationBar: isProfile
            ? RecruiterMobileNav(currentRoute: currentRoute)
            : null,
      );
    }
    return Scaffold(
      backgroundColor: context.themeCanvas(const Color(0xFFF8FAFC)),
      body: SafeArea(
        child: RecruiterSideNav(
          currentRoute: currentRoute,
          selectedRoute: selectedRoute,
          glowSelected: glowSelected,
          expandedWidth: context.sidebarWidth,
          workspace: Stack(
            key: const Key('recruiter-main-canvas'),
            children: [const RecruiterGradientBackground(), themedBody],
          ),
        ),
      ),
    );
  }
}
