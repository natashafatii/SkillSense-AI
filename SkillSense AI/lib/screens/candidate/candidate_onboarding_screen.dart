import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/green_gradient_background.dart';
import 'candidate_onboarding_screen_2.dart';

class CandidateOnboardingScreen extends StatelessWidget {
  const CandidateOnboardingScreen({super.key});

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

                        // Central Icon Graphic
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
                              Icons.my_location_rounded,
                              color: Color(0xFF34C759),
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          AppConstants.candidateOnboardingTitle,
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
                        Text(
                          AppConstants.candidateOnboardingSubtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Job Match Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _JobMatchRow(
                                title: 'Senior Django Developer',
                                matchScore: 91,
                                color: Color(0xFF34C759),
                              ),
                              const SizedBox(height: 24),
                              _JobMatchRow(
                                title: 'Frontend Engineer',
                                matchScore: 62,
                                color: const Color(
                                  0xFF34C759,
                                ).withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Spacer(),

                        // Page Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Dot(isActive: true),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Next Button (Pill shape)
                        SizedBox(
                          width: 220, // Match HR screen layout
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CandidateOnboardingScreen2(),
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
                              AppConstants.candidateNextButton,
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

class _JobMatchRow extends StatelessWidget {
  final String title;
  final int matchScore;
  final Color color;

  const _JobMatchRow({
    required this.title,
    required this.matchScore,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.publicSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '$matchScore%',
              style: GoogleFonts.publicSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(
                  0xFF34C759,
                ), // green to match candidate theme
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF), // light purple background
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: matchScore,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(flex: 100 - matchScore, child: const SizedBox()),
            ],
          ),
        ),
      ],
    );
  }
}

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
