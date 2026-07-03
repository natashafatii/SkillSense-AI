import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import 'hr_onboarding_screen_2.dart';

class HrOnboardingScreen extends StatelessWidget {
  const HrOnboardingScreen({super.key});

  void _onNext(BuildContext context) {
    // Navigate to HR Onboarding Screen 2
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HrOnboardingScreen2()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          const GradientBackground(),
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

                        // "For HR teams" Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.buttonBlue.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            color: Colors.transparent,
                          ),
                          child: Text(
                            'For HR teams',
                            style: GoogleFonts.publicSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.buttonBlue,
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
                              color: const Color(0xFFD4E6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.bar_chart_rounded,
                              color: AppColors.buttonBlue,
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          'AI screens 100%\nof applicants for you',
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
                          'Resumes are auto-scored & ranked.\nNo more reading 200 CVs.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Score Card
                        Container(
                          padding: const EdgeInsets.all(20),
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
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Senior Django Developer',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    '48 applicants',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Score rows
                              _ScoreRow(score: 91, color: AppColors.buttonBlue),
                              const SizedBox(height: 16),
                              _ScoreRow(score: 78, color: AppColors.buttonBlue),
                              const SizedBox(height: 16),
                              _ScoreRow(
                                score: 62,
                                color: const Color(
                                  0xFFE87B1E,
                                ), // Orange color from screenshot
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Spacer(),

                        // Page Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Dot(isActive: true),
                            const SizedBox(width: 8),
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: false),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Next Button (Pill shape)
                        SizedBox(
                          width: 220, // Shorter width to match screen 3
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _onNext(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.buttonBlue,
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shadowColor: AppColors.buttonBlue.withValues(
                                alpha: 0.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Next',
                              style: GoogleFonts.publicSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16), // Bottom padding
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

// ── Score Row Widget ─────────────────────────────────────────────────────────
class _ScoreRow extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreRow({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Person Icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: AppColors.buttonBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),

        // Progress Bar
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E9F2),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: score / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Score Text
        SizedBox(
          width: 28,
          child: Text(
            score.toString(),
            textAlign: TextAlign.right,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
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
        color: isActive ? AppColors.buttonBlue : const Color(0xFFD1D1D6),
        shape: BoxShape.circle,
      ),
    );
  }
}
