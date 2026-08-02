import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import '../login/login_role_selection_screen.dart';
import '../signup/role_selection_screen.dart';

/// The main welcome/onboarding screen for SkillSense AI.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          // Top gradient background
          const GradientBackground(),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          const Spacer(flex: 2), // Space from top
                          // Top section with star icon and app name
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Star icon with scale animation
                                    ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: SvgPicture.asset(
                                        'assets/images/logo.svg',
                                        width: 310,
                                        height: 310,
                                        fit: BoxFit.contain,
                                      ),
                                    ),

                                    // "SkillSense AI" branding text
                                    Transform.translate(
                                      offset: const Offset(
                                        0,
                                        -39,
                                      ), // Overlaps the SVG's empty padding
                                      child: SizedBox(
                                        width: 280,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Color(0xFF3459E9),
                                                  Color(0xFF1D3283),
                                                ],
                                              ).createShader(bounds),
                                          child: Text(
                                            'SkillSense AI',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.publicSans(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                              height: 1.0,
                                              letterSpacing: -1.28,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const Spacer(flex: 3), // Large gap
                          // Bottom section with heading, button, and login link
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // "Discover the Platform" heading
                                  Text(
                                    'Discover the\nPlatform',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1D1D1D),
                                      height: 1.1,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // "Create an account" button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const RoleSelectionScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4376F8,
                                        ), // vibrant blue
                                        foregroundColor: Colors.white,
                                        elevation:
                                            0, // flat button look in screenshot
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Create an account',
                                        style: GoogleFonts.publicSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // "You have an account? Log-in" row
                                  Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'You have an account ? ',
                                          style: GoogleFonts.publicSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF1D1D1D),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const LoginRoleSelectionScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Log-in',
                                            style: GoogleFonts.publicSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1D1D1D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 48), // Padding from bottom
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
