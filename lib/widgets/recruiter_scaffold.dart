import 'package:flutter/material.dart';
import 'recruiter_side_nav.dart';

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
    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(bottom: false, child: body),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Row(
          children: [
            RecruiterSideNav(
              currentRoute: currentRoute,
              selectedRoute: selectedRoute,
              glowSelected: glowSelected,
              expandedWidth: currentRoute == '/recruiter/profile' ? 244 : 272,
            ),
            Expanded(
              child: ClipRect(
                key: const Key('recruiter-main-canvas'),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
