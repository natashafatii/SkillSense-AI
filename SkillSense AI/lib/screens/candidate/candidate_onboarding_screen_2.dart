import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/green_gradient_background.dart';
import 'candidate_onboarding_screen_3.dart';

class CandidateOnboardingScreen2 extends StatelessWidget {
  const CandidateOnboardingScreen2({super.key});

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
                              Icons.manage_search_rounded,
                              color: Color(0xFF34C759),
                              size: 36,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Headings
                        Text(
                          'Interview on\nyour own time',
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
                          'Drop your Resume. AI extracts your skills,\nexperience and education in seconds',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Resume Extraction Card
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
                              // Resume file row
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF34C759),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'CV_Muhammad_2026.pdf — Pa...',
                                      style: GoogleFonts.publicSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Extracted skills label
                              Text(
                                'Extracted skills',
                                style: GoogleFonts.publicSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Skill tags
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  _SkillTag(label: 'Django'),
                                  _SkillTag(label: 'PostgreSQL'),
                                  _SkillTag(label: 'Python'),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Divider
                              Container(
                                height: 1,
                                color: const Color(0xFFF0F0F0),
                              ),

                              const SizedBox(height: 16),

                              // Experience row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.school_outlined,
                                    color: Color(0xFF34C759),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '4.5 yrs experience · BSc Computer Science',
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
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Spacer(),

                        // Page Indicators — 2nd dot active
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Dot(isActive: false),
                            SizedBox(width: 8),
                            _Dot(isActive: true),
                            SizedBox(width: 8),
                            _Dot(isActive: false),
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
                                      const CandidateOnboardingScreen3(),
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

// ── Skill Tag Widget ─────────────────────────────────────────────────────────
class _SkillTag extends StatelessWidget {
  final String label;

  const _SkillTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34C759).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.publicSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF34C759),
        ),
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
