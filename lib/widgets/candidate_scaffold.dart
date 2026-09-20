import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Widget _buildMobileBottomDock(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded, 'label': 'Home', 'route': '/candidate/home'},
      {'icon': Icons.adjust_rounded, 'label': 'Jobs', 'route': '/candidate/jobs'},
      {'icon': Icons.layers_rounded, 'label': 'Apps', 'route': '/candidate/applications'},
      {'icon': Icons.radio_button_checked_rounded, 'label': 'Lobby', 'route': '/candidate/interview-lobby'},
      {'icon': Icons.contrast_rounded, 'label': 'Profile', 'route': '/candidate/profile'},
    ];

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final String route = item['route'];
          final bool isActive = currentRoute == route;

          return InkWell(
            onTap: () {
              if (onNavigate != null) {
                onNavigate!(route);
              } else if (currentRoute != route) {
                Navigator.of(context).pushReplacementNamed(route);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF2EE6C8)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(height: 2),
                Text(
                  item['label'],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
