import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/green_gradient_background.dart';
import '../signup/candidate_register_screen.dart';
import 'candidate_onboarding_flow_web.dart';

class CandidateOnboardingFlow extends StatefulWidget {
  const CandidateOnboardingFlow({super.key});

  @override
  State<CandidateOnboardingFlow> createState() =>
      _CandidateOnboardingFlowState();
}

class _CandidateOnboardingFlowState extends State<CandidateOnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CandidateRegisterScreen()),
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      4,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _InteractiveDot(isActive: _currentPage == index),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.candidatePrimary,
                foregroundColor: AppColors.white,
                elevation: 10,
                shadowColor: AppColors.candidatePrimary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                _currentPage == 4
                    ? AppConstants.candidateCreateAccount
                    : AppConstants.candidateNextButton,
                style: GoogleFonts.publicSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return const CandidateOnboardingFlowWeb();
        }
        return Scaffold(
          backgroundColor: AppColors.backgroundBase,
          body: Stack(
            children: [
              const GreenGradientBackground(),
              SafeArea(
                child: Column(
                  children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.publicSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.candidatePrimary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      // ── Page 1 ──
                      _buildPage(
                        icon: Icons.my_location_rounded,
                        content: Column(
                          children: [
                            Text(
                              AppConstants.candidateTitle1,
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
                              AppConstants.candidateSub1,
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
                                    color: AppColors.candidatePrimary,
                                  ),
                                  const SizedBox(height: 24),
                                  _JobMatchRow(
                                    title: 'Frontend Engineer',
                                    matchScore: 62,
                                    color: AppColors.candidatePrimary.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Page 2 ──
                      _buildPage(
                        icon: Icons.manage_search_rounded,
                        content: Column(
                          children: [
                            Text(
                              AppConstants.candidateTitle2,
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
                              AppConstants.candidateSub2,
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
                                  Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: AppColors.candidatePrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: AppColors.white,
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
                                  Text(
                                    'Extracted skills',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SkillTag(label: 'Django'),
                                      _SkillTag(label: 'PostgreSQL'),
                                      _SkillTag(label: 'Python'),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(height: 1, color: AppColors.dividerLight),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.school_outlined, color: AppColors.candidatePrimary, size: 22),
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
                          ],
                        ),
                      ),

                      // ── Page 3 ──
                      _buildPage(
                        icon: Icons.mic_rounded,
                        content: Column(
                          children: [
                            Text(
                              AppConstants.candidateTitle3,
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
                              AppConstants.candidateSub3,
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
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: AppColors.candidatePrimary,
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
                                            color: AppColors.candidatePrimary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
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
                          ],
                        ),
                      ),

                      // ── Page 4 ──
                      _buildPage(
                        icon: Icons.star_outline_rounded,
                        content: Column(
                          children: [
                            Text(
                              AppConstants.candidateTitle4,
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
                              AppConstants.candidateSub4,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textGrey,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // AI Score Breakdown Card
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
                                  Text(
                                    'Your AI score breakdown',
                                    style: GoogleFonts.publicSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const _ScoreRow(
                                    label: 'Technical skills',
                                    score: '8.4/10',
                                    fraction: 0.84,
                                  ),
                                  const SizedBox(height: 20),
                                  const _ScoreRow(
                                    label: 'Communication',
                                    score: '7.1 / 10',
                                    fraction: 0.71,
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    height: 1,
                                    color: AppColors.dividerLight,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '"Strong technical depth. Focus on structuring longer answers more concisely."',
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
                          ],
                        ),
                      ),

                      // ── Page 5 ──
                      _buildPage(
                        icon: Icons.verified_rounded,
                        content: Column(
                          children: [
                            Text(
                              AppConstants.candidateTitle5,
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
                              AppConstants.candidateSub5,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textGrey,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const _PrivacyRow(
                              text: 'Resume data stays on our servers',
                            ),
                            const SizedBox(height: 12),
                            const _PrivacyRow(
                              text: 'Delete your account and data anytime',
                            ),
                            const SizedBox(height: 12),
                            const _PrivacyRow(
                              text: 'Scores shared only with your permission',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  /// Builds a single onboarding page with badge, icon, and scrollable content.
  Widget _buildPage({required IconData icon, required Widget content}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // "For job seekers" Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.candidatePrimary.withValues(alpha: 0.6),
                ),
                color: Colors.transparent,
              ),
              child: Text(
                AppConstants.candidateBadge,
                style: GoogleFonts.publicSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.candidatePrimary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Central Icon
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
                  color: AppColors.candidateLightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.candidatePrimary, size: 36),
              ),
            ),
            const SizedBox(height: 32),
            // Page-specific content
            content,
            const SizedBox(height: 16),
            _buildControls(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InteractiveDot extends StatelessWidget {
  final bool isActive;

  const _InteractiveDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.candidatePrimary : AppColors.candidateDotInactive,
        borderRadius: BorderRadius.circular(4),
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
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.candidateProgressBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: matchScore / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkillTag extends StatelessWidget {
  final String label;

  const _SkillTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.candidateLightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.publicSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.candidatePrimary,
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String score;
  final double fraction;

  const _ScoreRow({
    required this.label,
    required this.score,
    required this.fraction,
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
              label,
              style: GoogleFonts.publicSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.candidatePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                score,
                style: GoogleFonts.publicSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.candidatePrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.candidateProgressBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (fraction * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.candidatePrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                flex: 100 - (fraction * 100).round(),
                child: const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.candidatePrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.publicSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
