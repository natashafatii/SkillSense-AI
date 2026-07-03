import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import 'hr_onboarding_screen_3.dart';

class HrOnboardingScreen2 extends StatelessWidget {
  const HrOnboardingScreen2({super.key});

  void _onNext(BuildContext context) {
    // Navigate to HR Onboarding Screen 3
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HrOnboardingScreen3()),
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
                              Icons.monitor_rounded,
                              color: AppColors.buttonBlue,
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          'Run AI interviews\nNo scheduling hassle',
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
                          'T5 AI generates tailored questions. Retell\nconducts the interview. You just review.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Questions Card
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
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.publicSans(
                                    fontSize: 14,
                                    color: AppColors.textGrey,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Auto-generated for: ',
                                    ),
                                    TextSpan(
                                      text: 'Natasha Fatima.',
                                      style: GoogleFonts.publicSans(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Question Rows
                              _QuestionRow(
                                initial: 'B',
                                initialColor: AppColors.buttonBlue,
                                initialBgColor: const Color(0xFFEEF2FF),
                                text:
                                    'Describe a time you led a difficult project to completion',
                              ),
                              const SizedBox(height: 16),
                              _QuestionRow(
                                initial: 'T',
                                initialColor: AppColors.buttonBlue,
                                initialBgColor: const Color(0xFFEEF2FF),
                                text:
                                    'Walk me through your Django ORM and query optimisation experience',
                              ),
                              const SizedBox(height: 16),
                              _QuestionRow(
                                initial: 'S',
                                initialColor: const Color(
                                  0xFF2E7D32,
                                ), // Dark green
                                initialBgColor: const Color(
                                  0xFFE8F5E9,
                                ), // Light green
                                text:
                                    '"If you inherited poorly documented legacy code, how would you approach it?"',
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
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: true), // 2nd dot active
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

// ── Question Row Widget ──────────────────────────────────────────────────────
class _QuestionRow extends StatelessWidget {
  final String initial;
  final Color initialColor;
  final Color initialBgColor;
  final String text;

  const _QuestionRow({
    required this.initial,
    required this.initialColor,
    required this.initialBgColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circular Avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: initialBgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: initialColor,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Question Text
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              text,
              style: GoogleFonts.publicSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF333333),
                height: 1.4,
              ),
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
