import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_colors.dart';
import '../../widgets/gradient_background.dart';
import '../signup/hr_register_screen.dart';
import 'hr_onboarding_flow_web.dart';

class HrOnboardingFlow extends StatefulWidget {
  const HrOnboardingFlow({super.key});

  @override
  State<HrOnboardingFlow> createState() => _HrOnboardingFlowState();
}

class _HrOnboardingFlowState extends State<HrOnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HrRegisterScreen()),
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      _totalPages - 1,
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
            children: List.generate(_totalPages, (index) {
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
                backgroundColor: AppColors.hrPrimary,
                foregroundColor: AppColors.white,
                elevation: 10,
                shadowColor: AppColors.hrPrimary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                _currentPage == 3
                    ? AppConstants.hrCreateAccount
                    : AppConstants.hrNextButton,
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
          return const HrOnboardingFlowWeb();
        }
        return Scaffold(
          backgroundColor: AppColors.hrBackground,
          body: Stack(
            children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.publicSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hrPrimary,
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _Page1(controls: _buildControls()),
                      _Page2(controls: _buildControls()),
                      _Page3(controls: _buildControls()),
                      _Page4(controls: _buildControls()),
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
}

// ─────────────────────────────────────────────
//  Shared dot widget
// ─────────────────────────────────────────────
class _InteractiveDot extends StatelessWidget {
  final bool isActive;
  const _InteractiveDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.hrPrimary : AppColors.hrDotInactive,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared header badge
// ─────────────────────────────────────────────
class _HrBadge extends StatelessWidget {
  const _HrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hrPrimary.withValues(alpha: 0.5)),
        color: AppColors.white.withValues(alpha: 0.6),
      ),
      child: Text(
        AppConstants.hrBadge,
        style: GoogleFonts.publicSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.hrPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared icon card
// ─────────────────────────────────────────────
class _IconCard extends StatelessWidget {
  final IconData icon;
  const _IconCard({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.white,
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
          color: AppColors.hrLightBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppColors.hrPrimary, size: 36),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 1 — AI screens 100% of applicants
// ─────────────────────────────────────────────
class _Page1 extends StatelessWidget {
  final Widget controls;
  const _Page1({required this.controls});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const _HrBadge(),
          const SizedBox(height: 28),
          const _IconCard(icon: Icons.bar_chart_rounded),
          const SizedBox(height: 28),
          Text(
            AppConstants.hrTitle1,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.hrTextDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppConstants.hrSub1,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.hrTextGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Senior Django Developer',
                      style: GoogleFonts.publicSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.hrTextDark,
                      ),
                    ),
                    Text(
                      '48 applicants',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: AppColors.hrTextGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _ApplicantBar(score: 91, color: AppColors.hrPrimary),
                const SizedBox(height: 12),
                const _ApplicantBar(score: 78, color: AppColors.hrPrimary),
                const SizedBox(height: 12),
                const _ApplicantBar(score: 62, color: AppColors.hrOrange),
              ],
            ),
          ),
          const SizedBox(height: 16),
          controls,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ApplicantBar extends StatelessWidget {
  final int score;
  final Color color;
  const _ApplicantBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.hrBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.hrPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 1, color: AppColors.hrDivider),
                FractionallySizedBox(
                  widthFactor: score / 100,
                  child: Container(height: 8, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score',
          style: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 2 — Run AI interviews
// ─────────────────────────────────────────────
class _Page2 extends StatelessWidget {
  final Widget controls;
  const _Page2({required this.controls});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const _HrBadge(),
          const SizedBox(height: 28),
          const _IconCard(icon: Icons.monitor_rounded),
          const SizedBox(height: 28),
          Text(
            AppConstants.hrTitle2,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.hrTextDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppConstants.hrSub2,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.hrTextGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      color: AppColors.hrTextGrey,
                    ),
                    children: [
                      const TextSpan(text: 'Auto-generated for: '),
                      TextSpan(
                        text: 'Natasha F.',
                        style: GoogleFonts.publicSans(
                          fontWeight: FontWeight.w700,
                          color: AppColors.hrTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _InterviewQuestion(
                  avatar: 'B',
                  color: AppColors.hrPrimary,
                  text:
                      'Describe a time you led a difficult project to completion',
                ),
                const SizedBox(height: 12),
                const _InterviewQuestion(
                  avatar: 'T',
                  color: AppColors.hrTextGrey,
                  text:
                      'Walk me through your Django ORM and query optimisation experience',
                ),
                const SizedBox(height: 12),
                const _InterviewQuestion(
                  avatar: 'S',
                  color: AppColors.hrGreen,
                  text:
                      '"If you inherited poorly documented legacy code, how would you approach it?"',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          controls,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InterviewQuestion extends StatelessWidget {
  final String avatar;
  final Color color;
  final String text;

  const _InterviewQuestion({
    required this.avatar,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            avatar,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.publicSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.hrTextMedium,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 3 — Real-time body language analysis
// ─────────────────────────────────────────────
class _Page3 extends StatelessWidget {
  final Widget controls;
  const _Page3({required this.controls});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const _HrBadge(),
          const SizedBox(height: 28),
          const _IconCard(icon: Icons.track_changes_rounded),
          const SizedBox(height: 28),
          Text(
            AppConstants.hrTitle3,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.hrTextDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppConstants.hrSub3,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.hrTextGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SESSION ANALYSIS — NATASHA F.',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hrTextLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _AnalysisStat(
                        value: '87%',
                        label: 'GAZE ON-\nSCREEN',
                        valueColor: AppColors.hrGreen,
                      ),
                    ),
                    Container(width: 1, height: 50, color: AppColors.hrDivider),
                    Expanded(
                      child: _AnalysisStat(
                        value: '74%',
                        label: 'CONFIDENCE\nSCORE',
                        valueColor: AppColors.hrPrimary,
                      ),
                    ),
                    Container(width: 1, height: 50, color: AppColors.hrDivider),
                    Expanded(
                      child: _AnalysisStat(
                        value: 'LOW',
                        label: 'CHEATING\nRISK',
                        valueColor: AppColors.hrGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          controls,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AnalysisStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _AnalysisStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.hrTextLight,
            letterSpacing: 0.4,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 4 — Trusted ranked recommendations
// ─────────────────────────────────────────────
class _Page4 extends StatelessWidget {
  final Widget controls;
  const _Page4({required this.controls});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const _HrBadge(),
          const SizedBox(height: 28),
          const _IconCard(icon: Icons.star_border_rounded),
          const SizedBox(height: 28),
          Text(
            AppConstants.hrTitle4,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.hrTextDark,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppConstants.hrSub4,
            textAlign: TextAlign.center,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.hrTextGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Rankings card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SENIOR DJANGO DEVELOPER — FINAL\nRANKINGS',
                  style: GoogleFonts.publicSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hrTextLight,
                    letterSpacing: 0.8,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const _RankingRow(
                  rank: 1,
                  name: 'Zohaib A.',
                  label: 'STRONG YES',
                  labelColor: AppColors.hrGreen,
                  labelBg: AppColors.hrLightGreen,
                ),
                const Divider(height: 24, color: AppColors.hrBackground),
                const _RankingRow(
                  rank: 2,
                  name: 'Umar Z.',
                  label: 'YES',
                  labelColor: AppColors.hrPrimary,
                  labelBg: AppColors.hrLightBlueAlt,
                ),
                const Divider(height: 24, color: AppColors.hrBackground),
                const _RankingRow(
                  rank: 3,
                  name: 'Natasha F.',
                  label: 'MAYBE',
                  labelColor: AppColors.hrOrange,
                  labelBg: AppColors.hrLightOrange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          controls,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final String name;
  final String label;
  final Color labelColor;
  final Color labelBg;

  const _RankingRow({
    required this.rank,
    required this.name,
    required this.label,
    required this.labelColor,
    required this.labelBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '#$rank',
          style: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.hrTextLight,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.hrDivider,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.publicSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.hrTextDark,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.publicSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}
