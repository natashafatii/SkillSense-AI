// lib/screens/login_role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import 'login_screen.dart';
import '../signup/role_selection_screen.dart';

/// Login role selection screen — shown BEFORE the login screen.
/// User selects Recruiter/HR or Job Seeker, then proceeds to [LoginScreen].
class LoginRoleSelectionScreen extends StatefulWidget {
  const LoginRoleSelectionScreen({super.key});

  @override
  State<LoginRoleSelectionScreen> createState() =>
      _LoginRoleSelectionScreenState();
}

class _LoginRoleSelectionScreenState extends State<LoginRoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() => _selectedRole = role);
  }

  void _onContinue() {
    if (_selectedRole == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(selectedRole: _selectedRole),
      ),
    );
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          // ── Same gradient background as WelcomeScreen & other screens ──
          const GradientBackground(),

          // ── Scrollable content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 28),

                              // ── Logo (same as LoginScreen) ──
                              Center(
                                child: SvgPicture.asset(
                                  'assets/images/logo.svg',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // ── Header: "Who are you signing in as?" ──
                              Text(
                                'Who are you\nsigning in as?',
                                style: GoogleFonts.publicSans(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select your role to continue',
                                style: GoogleFonts.publicSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF888888),
                                ),
                              ),

                              const SizedBox(height: 36),

                              // ── Recruiter / HR Card ──
                              _LoginRoleCard(
                                title: 'Recruiter / HR',
                                description: 'Post jobs and manage candidates',
                                icon: Icons.work_outline_rounded,
                                isSelected: _selectedRole == 'recruiter',
                                onTap: () => _selectRole('recruiter'),
                              ),
                              const SizedBox(height: 16),

                              // ── Job Seeker Card ──
                              _LoginRoleCard(
                                title: 'Job Seeker',
                                description: 'Find jobs and get AI interviewed',
                                icon: Icons.person_outline_rounded,
                                isSelected: _selectedRole == 'job_seeker',
                                onTap: () => _selectRole('job_seeker'),
                              ),

                              const SizedBox(height: 32),
                              const Spacer(),

                              // ── Continue button ──
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _selectedRole != null
                                      ? _onContinue
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.buttonBlue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppColors
                                        .buttonBlue
                                        .withValues(alpha: 0.45),
                                    disabledForegroundColor: Colors.white
                                        .withValues(alpha: 0.7),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    'Continue',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── "Don't have an account? Sign Up" ──
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: GoogleFonts.publicSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF888888),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _goToSignUp,
                                      child: Text(
                                        'Sign Up',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.linkBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selectable flat role card (matches screenshot style) ─────────────────────
class _LoginRoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LoginRoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.buttonBlue : const Color(0xFFE8E8E8),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.buttonBlue.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.buttonBlue, size: 26),
            ),
            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.publicSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF888888),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : Colors.white,
                border: Border.all(
                  color: isSelected
                      ? AppColors.buttonBlue
                      : const Color(0xFFCCCCCC),
                  width: isSelected ? 2.0 : 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.buttonBlue,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
