import 'package:flutter/material.dart';
import 'package:skillsense_ai/screens/signup/signup_role_selection_screen.dart';
import 'package:skillsense_ai/screens/login/role_selection_screen_web.dart';
import 'package:skillsense_ai/screens/login/role_selection_screen_mobile.dart';
import 'package:skillsense_ai/screens/login/login_screen.dart';


/// Role selection screen where users choose between Recruiter/HR and Job Seeker.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(selectedRole: _selectedRole),
      ),
    );
  }

  void _onSignUpTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupRoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return RoleSelectionScreenWeb(
            selectedRole: _selectedRole,
            onRoleSelected: _selectRole,
            onContinue: _onContinue,
            onSignUpTap: _onSignUpTap,
            fadeAnimation: _fadeAnimation,
            slideAnimation: _slideAnimation,
          );
        } else {
          return RoleSelectionScreenMobile(
            selectedRole: _selectedRole,
            onRoleSelected: _selectRole,
            onContinue: _onContinue,
            onSignUpTap: _onSignUpTap,
            fadeAnimation: _fadeAnimation,
            slideAnimation: _slideAnimation,
          );
        }
      },
    );
  }
}
