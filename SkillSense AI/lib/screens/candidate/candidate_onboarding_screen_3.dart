import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/green_gradient_background.dart';
import 'candidate_onboarding_screen_4.dart';

class CandidateOnboardingScreen3 extends StatelessWidget {
  const CandidateOnboardingScreen3({super.key});

  // Waveform bar heights (simulate live audio bars)
  static const List<double> _waveHeights = [
    16,
    28,
    40,
    52,
    44,
    60,
    48,
    56,
    36,
    44,
    52,
    32,
    20,
  ];

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

                        // Central Icon Graphic — microphone
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
                              Icons.mic_rounded,
                              color: Color(0xFF34C759),
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          'AI-matched jobs,\njust for you',
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
                          'A real-time AI voice agent conducts your\ninterview',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // AI Interviewer Live Card
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row: Live dot + title + Q count
                              Row(
                                children: [
                                  // Live green dot
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF34C759),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'AI interviewer — LIVE',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Q 3 of 8',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Waveform bars
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: _waveHeights.map((h) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3.0,
                                    ),
                                    child: Container(
                                      width: 6,
                                      height: h,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34C759),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 20),

                              // Quote text
                              Text(
                                '"Tell me about a time you led a challenging project and what the outcome was..."',
                                style: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textGrey,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Spacer(),

                        // Page Indicators — 3rd dot active
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: true),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Next Button
                        SizedBox(
                          width: 220,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CandidateOnboardingScreen4(),
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
