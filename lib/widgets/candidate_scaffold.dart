import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import 'candidate_mobile_nav.dart';
import 'candidate_side_nav.dart';
import 'green_gradient_background.dart';

class CandidateScaffold extends StatelessWidget {
  static const mobileBreakpoint = 900.0;

  final String currentRoute;
  final Widget body;
  final Widget? mobileDrawer;
  final bool hideSideNav;
  final Function(String route)? onNavigate;

  const CandidateScaffold({
    super.key,
    required this.currentRoute,
    required this.body,
    this.mobileDrawer,
    this.hideSideNav = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < mobileBreakpoint;

    if (hideSideNav) {
      return Scaffold(
        backgroundColor: context.themeCanvas(const Color(0xFFF8FAFC)),
        body: Stack(children: [const GreenGradientBackground(), body]),
      );
    }

    return Scaffold(
      backgroundColor: context.themeCanvas(const Color(0xFFF8FAFC)),
      drawer: isMobile ? mobileDrawer : null,
      body: Stack(
        children: [
          const GreenGradientBackground(),
          SafeArea(
            bottom: false,
            child: isMobile
                ? body
                : CandidateSideNav(
                    currentRoute: currentRoute,
                    onNavigate: onNavigate,
                    workspace: body,
                  ),
          ),

          // Mobile Bottom Dock (Mobile Viewport < 900px)
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomDock(context),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomDock(BuildContext context) =>
      CandidateMobileNav(currentRoute: currentRoute, onNavigate: onNavigate);
}
