import 'package:flutter/material.dart';
import 'candidate_mobile_nav.dart';
import 'candidate_side_nav.dart';

class CandidateScaffold extends StatelessWidget {
  final String currentRoute;
  final Widget body;
  final bool hideSideNav;
  final Function(String route)? onNavigate;

  const CandidateScaffold({
    super.key,
    required this.currentRoute,
    required this.body,
    this.hideSideNav = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    if (hideSideNav) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background layout
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Desktop Web Rail
                if (!isMobile)
                  CandidateSideNav(
                    currentRoute: currentRoute,
                    onNavigate: onNavigate,
                  ),

                // Main Canvas (Reflows automatically when sidebar width animates)
                Expanded(
                  child: body,
                ),
              ],
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

  Widget _buildMobileBottomDock(BuildContext context) => CandidateMobileNav(
    currentRoute: currentRoute,
    onNavigate: onNavigate,
  );
}
