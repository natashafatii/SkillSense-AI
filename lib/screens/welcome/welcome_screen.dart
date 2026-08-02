import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../login/role_selection_screen.dart';
import '../signup/signup_role_selection_screen.dart';
import 'welcome_screen_web.dart';

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
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return const WelcomeScreenWeb();
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2FF),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 48),

                          // ── Star / Compass icon ─────────────────────────
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: SvgPicture.asset(
                              'assets/images/logo.svg',
                              width: 130,
                              height: 130,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── App name ────────────────────────────────────
                          ShaderMask(
                            shaderCallback:
                                (bounds) => const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF3A5AF5),
                                    Color(0xFF1D35B4),
                                  ],
                                ).createShader(bounds),
                            child: Text(
                              'SkillSense AI',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // ── Italic tagline ──────────────────────────────
                          Text(
                            'Intelligent recruitment, simplified',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF64748B),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── AI-powered badge ────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFDDE3FF),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4376F8,
                                  ).withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/logo.svg',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'AI-powered recruitment',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4376F8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Headline ─────────────────────────────────────
                          SlideTransition(
                            position: _slideAnimation,
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.18,
                                  letterSpacing: -0.5,
                                ),
                                children: [
                                  const TextSpan(text: 'Discover the\n'),
                                  WidgetSpan(
                                    child: ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback:
                                          (bounds) => const LinearGradient(
                                            colors: [
                                              Color(0xFF4376F8),
                                              Color(0xFF6C63FF),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                      child: Text(
                                        'right talent',
                                        style: GoogleFonts.inter(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          height: 1.18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ', faster'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Subcopy ──────────────────────────────────────
                          Text(
                            'Screen résumés, run structured interviews and rank candidates with explainable AI.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF64748B),
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── Create an account button ─────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SignupRoleSelectionScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.webRoleHr,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const SizedBox.shrink(),
                              label: Text(
                                'Create an account',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ── Already have an account? ─────────────────────
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RoleSelectionScreen(),
                                ),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Already have an account? ',
                                  ),
                                  TextSpan(
                                    text: 'Log in',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.webRoleHr,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // ── Footer ───────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                                children: [
                                  const TextSpan(text: 'Trusted by '),
                                  TextSpan(
                                    text: 'HR teams',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'recruitment agencies',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
