import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/green_gradient_background.dart';
import '../signup/candidate_register_screen.dart';

class CandidateOnboardingScreen5 extends StatelessWidget {
  const CandidateOnboardingScreen5({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          const GreenGradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // "For job seekers" Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF34C759,
                              ).withValues(alpha: 0.6),
                            ),
                            color: Colors.transparent,
                          ),
                          child: Text(
                            AppConstants.candidateOnboardingBadge,
                            style: GoogleFonts.publicSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF34C759),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Central Icon Graphic — shield / verified checkmark
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF34C759),
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'Your data\nstays yours',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          'Your data is processed on our own servers.\nNever sent to third-party AI services.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Feature List — 3 privacy bullet rows
                        _PrivacyRow(
                          text: 'Resume data stays on our servers',
                        ),
                        const SizedBox(height: 12),
                        _PrivacyRow(
                          text: 'Delete your account and data anytime',
                        ),
                        const SizedBox(height: 12),
                        _PrivacyRow(
                          text: 'Scores shared only with your permission',
                        ),

                        const SizedBox(height: 32),
                        const Spacer(),

                        // Page Indicators — 5th dot active
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: true), // 5th dot active
                          ],
                        ),

                        const SizedBox(height: 24),

                        // "Create my account" Button — 220 width pill matching HR onboarding screen 4
                        SizedBox(
                          width: 220,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CandidateRegisterScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34C759),
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shadowColor: const Color(
                                0xFF34C759,
                              ).withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Create my account',
                              style: GoogleFonts.publicSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
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

// ── Privacy Feature Row ───────────────────────────────────────────────────────
class _PrivacyRow extends StatelessWidget {
  final String text;

  const _PrivacyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Green checkmark circle
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Feature text
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.publicSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page Indicator Dot ───────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool isActive;

  const _Dot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF34C759) : const Color(0xFFD1D1D6),
        shape: BoxShape.circle,
      ),
    );
  }
}
