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
      final customMobileHeader =
          (currentRoute == '/recruiter/create-role' &&
              MediaQuery.sizeOf(context).width < 900) ||
          currentRoute == '/recruiter/pipeline' ||
          currentRoute == '/recruiter/rankings' ||
          currentRoute == '/recruiter/analytics' ||
          currentRoute == '/recruiter/live-monitor' ||
          currentRoute == '/recruiter/interview-review' ||
          currentRoute == '/recruiter/company-team' ||
          currentRoute == '/recruiter/scoring-model' ||
          currentRoute == '/recruiter/schedule-interview' ||
          currentRoute == '/recruiter/candidate-report' ||
          currentRoute.startsWith('/recruiter/jobs/');
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: customMobileHeader
            ? null
            : AppBar(
                toolbarHeight: 48,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                title: const Text(
                  'SkillSense',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                leading: Builder(
                  builder: (context) => IconButton(
                    key: const Key('recruiter-menu'),
                    icon: const Icon(Icons.menu),
                    tooltip: 'Open navigation',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
        drawer: Drawer(
          width: 272,
          child: SafeArea(
            child: RecruiterSideNav(
              currentRoute: currentRoute,
              selectedRoute: selectedRoute,
              glowSelected: glowSelected,
              inDrawer: true,
            ),
          ),
        ),
        body: body,
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
