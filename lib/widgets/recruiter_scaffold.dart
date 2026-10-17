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
          currentRoute == '/recruiter/scoring-model' ||
          currentRoute == '/recruiter/schedule-interview' ||
          currentRoute == '/recruiter/candidate-report' ||
          currentRoute == '/recruiter/profile' ||
          currentRoute.startsWith('/recruiter/jobs/');
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: customMobileHeader
            ? null
            : AppBar(
                toolbarHeight: 48,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                automaticallyImplyLeading: false,
                title: const Text(
                  'SkillSense',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
