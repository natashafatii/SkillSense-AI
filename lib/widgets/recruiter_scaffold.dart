import 'package:flutter/material.dart';
import 'recruiter_side_nav.dart';

/// Keeps one navigation surface around every recruiter route.
class RecruiterScaffold extends StatelessWidget {
  final String currentRoute;
  final Widget body;
  const RecruiterScaffold({
    super.key,
    required this.currentRoute,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
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
            child: RecruiterSideNav(currentRoute: currentRoute, inDrawer: true),
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
            RecruiterSideNav(currentRoute: currentRoute),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
