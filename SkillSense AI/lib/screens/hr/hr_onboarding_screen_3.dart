import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import 'hr_onboarding_screen_4.dart';

class HrOnboardingScreen3 extends StatelessWidget {
  const HrOnboardingScreen3({super.key});

  void _onNext(BuildContext context) {
    // Navigate to HR Onboarding Screen 4
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HrOnboardingScreen4()),
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
                              Icons.track_changes_rounded,
                              color: AppColors.buttonBlue,
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          'Real-time body\nlanguage analysis',
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
                          'MediaPipe tracks gaze, YOLOv8 flags\ndistractions (auto during live interviews)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Session Analysis Card
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
                              Center(
                                child: Text(
                                  'SESSION ANALYSIS — NATASHA F.',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9EABC0),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Metrics Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      value: '87%',
                                      valueColor: const Color(
                                        0xFF00897B,
                                      ), // Teal
                                      label: 'GAZE ON-\nSCREEN',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      value: '74%',
                                      valueColor: AppColors.buttonBlue,
                                      label: 'CONFIDENCE\nSCORE',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      value: 'LOW',
                                      valueColor: const Color(
                                        0xFF4CAF50,
                                      ), // Green
                                      label: 'CHEATING\nRISK',
                                    ),
                                  ),
                                ],
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
                            _Dot(isActive: false),
                            const SizedBox(width: 8),
                            _Dot(isActive: true), // 3rd dot active
                            const SizedBox(width: 8),
                            _Dot(isActive: false),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Next Button (Pill shape)
                        SizedBox(
                          width: 220, // Shorter width as per screenshot
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

// ── Metric Card Widget ───────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String value;
  final Color valueColor;
  final String label;

  const _MetricCard({
    required this.value,
    required this.valueColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.publicSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB0B0B0),
              height: 1.2,
              letterSpacing: 0.5,
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
        color: isActive ? AppColors.buttonBlue : const Color(0xFFD1D1D6),
        shape: BoxShape.circle,
      ),
    );
  }
}
