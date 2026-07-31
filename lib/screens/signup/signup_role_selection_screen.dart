import 'package:flutter/material.dart';
import 'package:skillsense_ai/screens/candidate/candidate_onboarding_flow.dart';
import 'package:skillsense_ai/screens/hr/hr_onboarding_flow.dart';
import 'package:skillsense_ai/screens/login/role_selection_screen.dart';
import 'package:skillsense_ai/screens/signup/signup_role_selection_screen_web.dart';
import 'package:skillsense_ai/screens/login/role_selection_screen_mobile.dart';

/// Responsive wrapper for the signup role selection flow.
/// > 900 px → [SignupRoleSelectionScreenWeb]
/// ≤ 900 px → [RoleSelectionScreenMobile] (shared mobile layout)
class SignupRoleSelectionScreen extends StatefulWidget {
  const SignupRoleSelectionScreen({super.key});

  @override
  State<SignupRoleSelectionScreen> createState() =>
      _SignupRoleSelectionScreenState();
}

class _SignupRoleSelectionScreenState extends State<SignupRoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _onContinue() {
    if (_selectedRole == 'recruiter') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HrOnboardingFlow()),
      );
    } else if (_selectedRole == 'job_seeker') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CandidateOnboardingFlow()),
      );
    }
  }

  void _onLoginTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return SignupRoleSelectionScreenWeb(
            selectedRole: _selectedRole,
            onRoleSelected: _selectRole,
            onContinue: _onContinue,
            onLoginTap: _onLoginTap,
            fadeAnimation: _fadeAnimation,
            slideAnimation: _slideAnimation,
          );
        } else {
          return RoleSelectionScreenMobile(
            selectedRole: _selectedRole,
            onRoleSelected: _selectRole,
            onContinue: _onContinue,
            onSignUpTap: _onLoginTap,
            fadeAnimation: _fadeAnimation,
            slideAnimation: _slideAnimation,
          );
        }
      },
    );
  }
}
