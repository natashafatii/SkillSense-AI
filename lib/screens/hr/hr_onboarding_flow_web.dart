import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import '../signup/hr_register_screen.dart';

/// Web version of the HR Onboarding Flow split layout.
class HrOnboardingFlowWeb extends StatefulWidget {
  const HrOnboardingFlowWeb({super.key});

  @override
  State<HrOnboardingFlowWeb> createState() => _HrOnboardingFlowWebState();
}

class _HrOnboardingFlowWebState extends State<HrOnboardingFlowWeb> {
  int _currentPage = 0;
  static const int _totalPages = 4;

  static const List<Map<String, dynamic>> _leftPanelData = [
    {
      'eyebrow': 'FOR HR TEAMS',
      'title': 'A shortlist in minutes, not\nevenings.',
      'body':
          'Every application is read, matched against the role semantically, and ranked. You open a sorted pipeline instead of a folder of PDFs.',
      'highlight': 'shortlist',
      'points': [
        'Every resume read and ranked automatically',
        'Skill overlap and match score per applicant',
        'Nothing rejected without a human decision',
      ],
    },
    {
      'eyebrow': 'FOR HR TEAMS',
      'title': 'Interview questions,\ndrafted from the job.',
      'body':
          'T5 reads the job description and drafts behavioral, technical, and situational questions. Retell conducts the interview — you just review.',
      'highlight': 'drafted',
      'points': [
        'Every resume read and ranked automatically',
        'Questions generated per role, no scheduling needed',
        'Live sessions monitored in real time',
      ],
    },
    {
      'eyebrow': 'FOR HR TEAMS',
      'title': 'Watch the interview as it\nhappens.',
      'body':
          'A read-only live view: transcript, attention, and an integrity band. Alerts only when something genuinely needs a human.',
      'highlight': 'Watch',
      'points': [
        'Live transcript and gaze indicator',
        'Integrity shown as a band, never a raw score',
        'One alert per incident — no alarm fatigue',
      ],
    },
    {
      'eyebrow': 'FOR HR TEAMS',
      'title': 'Every score comes with its\nreasons.',
      'body':
          'Not a black box: each score ships with what pushed it up, what pulled it down, and a plain-English verdict you can act on immediately.',
      'highlight': 'reasons.',
      'points': [
        'Drivers shown for every single score',
        'Plain-language summary, no ML jargon',
        'Trusted, ranked recommendations — ready to act on',
      ],
    },
  ];

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HrRegisterScreen()),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HrRegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLeft = _leftPanelData[_currentPage];

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = Responsive.getSpacing(
            context,
            mobile: 24,
            tablet: 32,
            desktop: 32,
          );
          final double verticalPadding = constraints.maxHeight * 0.05;

          return Stack(
            children: [
              // ── BACKGROUND LAYER ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: dark gradient panel
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-0.5, -0.866),
                              end: Alignment(0.5, 0.866),
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                AppColors.webPanelGradientStart,
                                AppColors.webPanelGradientMid,
                                AppColors.webPanelGradientEnd,
                              ],
                            ),
                          ),
                        ),
                        // Radial glow top-right
                        Positioned(
                          top: -300,
                          right: -300,
                          child: Container(
                            width: 800,
                            height: 800,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [AppColors.webGlow, Colors.transparent],
                                stops: [0.0, 0.8],
                              ),
                            ),
                          ),
                        ),
                        // Hairline right edge
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 1,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.webHairline,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: light lavender/white
                  Expanded(child: Container(color: const Color(0xFFF5F7FF))),
                ],
              ),

              // ── CONTENT LAYER ─────────────────────────────────────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.webLayoutMaxWidth,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── LEFT PANEL ─────────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Brand row
                              Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/logo.svg',
                                    height: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'SkillSense AI',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.01,
                                    ),
                                  ),
                                ],
                              ),

                              // Fixed gap — logo to headline (max 72px)
                              SizedBox(height: verticalPadding.clamp(40, 72)),

                              // Dynamic Headline block per page
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Column(
                                  key: ValueKey<int>(_currentPage),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Eyebrow
                                    Row(
                                      children: [
                                        Container(
                                          width: 18,
                                          height: 1,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          currentLeft['eyebrow'] as String,
                                          style: GoogleFonts.inter(
                                            color: AppColors.webEyebrow,
                                            fontSize: Responsive.getFontSize(
                                              context,
                                              mobile: 10,
                                              desktop: 11.5,
                                            ),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),

                                    // Main headline with italic shader highlight
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth:
                                            Responsive.leftPanelContentMaxWidth,
                                      ),
                                      child: _buildFormattedHeadline(
                                        context,
                                        currentLeft['title'] as String,
                                        currentLeft['highlight'] as String,
                                      ),
                                    ),
                                    const SizedBox(height: 22),

                                    // Subcopy
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth:
                                            Responsive.leftPanelContentMaxWidth,
                                      ),
                                      child: Text(
                                        currentLeft['body'] as String,
                                        style: GoogleFonts.inter(
                                          color: AppColors.webSubcopy,
                                          fontSize: 15.5,
                                          height: 1.75,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Bullet points
                                    ...List<Widget>.from(
                                      (currentLeft['points'] as List<String>)
                                          .map(
                                            (pt) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              child: _BulletPoint(
                                                text: pt,
                                                isCurrentPagePoint: true,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 60),

                              // Footer
                              Text(
                                '© 2026 SkillSense AI · Bahria University',
                                style: GoogleFonts.inter(
                                  color: AppColors.webFooterText,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── RIGHT PANEL ────────────────────────────────────────
                      Expanded(
                        child: Stack(
                          children: [
                            // Interactive Onboarding Card Content
                            Positioned.fill(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: verticalPadding,
                                      horizontal: horizontalPadding,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth:
                                            Responsive.rightPanelContentMaxWidth,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 40),
                                          // HR Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          color: AppColors.webRoleHr.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                        child: Text(
                                          AppConstants.hrBadge,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.webRoleHr,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Icon Card
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          _getPageIcon(_currentPage),
                                          color: AppColors.webRoleHr,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Page Title
                                      Text(
                                        _getPageTitle(_currentPage),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.fraunces(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Page Subtitle
                                      Text(
                                        _getPageSubtitle(_currentPage),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFF64748B),
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 28),

                                      // Dynamic Card Preview
                                      _buildRightCardPreview(_currentPage),
                                      const SizedBox(height: 28),

                                      // Pagination Dots
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(_totalPages, (
                                          index,
                                        ) {
                                          final bool isActive =
                                              index == _currentPage;
                                          return GestureDetector(
                                            onTap: () => setState(
                                              () => _currentPage = index,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              width: isActive ? 20 : 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? AppColors.webRoleHr
                                                    : const Color(0xFFCBD5E1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 28),

                                      // Next / Finish CTA
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed: _nextPage,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.webRoleHr,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                          child: Text(
                                            _currentPage == 3
                                                ? AppConstants.hrCreateAccount
                                                : AppConstants.hrNextButton,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
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

                            // Skip button top right
                            Positioned(
                              top: verticalPadding,
                              right: horizontalPadding,
                              child: TextButton(
                                onPressed: _skip,
                                child: Text(
                                  'Skip',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.webRoleHr,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Headline helper with ShaderMask for target highlight word ─────────────
  Widget _buildFormattedHeadline(
    BuildContext context,
    String fullTitle,
    String highlightWord,
  ) {
    final double fontSize = Responsive.getFontSize(
      context,
      mobile: 30,
      tablet: 34,
      desktop: 40,
    );

    if (!fullTitle.contains(highlightWord)) {
      return Text(
        fullTitle,
        style: GoogleFonts.fraunces(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.18,
        ),
      );
    }

    final parts = fullTitle.split(highlightWord);

    return RichText(
      text: TextSpan(
        style: GoogleFonts.fraunces(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.18,
          letterSpacing: -0.01,
        ),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  AppColors.webHeadlineFairlyStart,
                  AppColors.webHeadlineFairlyEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                highlightWord,
                style: GoogleFonts.fraunces(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.18,
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }

  // Helper icons for page cards
  IconData _getPageIcon(int page) {
    switch (page) {
      case 0:
        return Icons.bar_chart_rounded;
      case 1:
        return Icons.hearing_rounded;
      case 2:
        return Icons.track_changes_rounded;
      case 3:
      default:
        return Icons.star_border_rounded;
    }
  }

  String _getPageTitle(int page) {
    switch (page) {
      case 0:
        return 'AI screens 100%\nof applicants for you';
      case 1:
        return 'Run AI interviews\nNo scheduling hassle';
      case 2:
        return 'Real-time body\nlanguage analysis';
      case 3:
      default:
        return 'Trusted ranked\nrecommendations';
    }
  }

  String _getPageSubtitle(int page) {
    switch (page) {
      case 0:
        return 'Resumes are auto-scored & ranked.\nNo more reading 200 CVs.';
      case 1:
        return 'T5 AI generates tailored questions. Retell\nconducts the interview. You just review.';
      case 2:
        return 'MediaPipe tracks gaze, YOLOv8 flags\ndistractions (auto during live interviews)';
      case 3:
      default:
        return 'XGBoost ranks candidates with clear,\nexplainable insights.';
    }
  }

  Widget _buildRightCardPreview(int page) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _getCardBody(page),
    );
  }

  Widget _getCardBody(int page) {
    switch (page) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Senior Django Developer',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '48 applicants',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _WebApplicantBar(score: 91, color: AppColors.webRoleHr),
            const SizedBox(height: 10),
            const _WebApplicantBar(score: 78, color: AppColors.webRoleHr),
            const SizedBox(height: 10),
            const _WebApplicantBar(score: 62, color: Color(0xFFF59E0B)),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                children: [
                  const TextSpan(text: 'Auto-generated for: '),
                  TextSpan(
                    text: 'Natasha F.',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _WebInterviewQuestion(
              avatar: 'B',
              color: AppColors.webRoleHr,
              text: 'Describe a time you led a difficult project to completion',
            ),
            const SizedBox(height: 10),
            const _WebInterviewQuestion(
              avatar: 'T',
              color: Color(0xFF94A3B8),
              text:
                  'Walk me through your Django ORM and query optimisation experience',
            ),
            const SizedBox(height: 10),
            const _WebInterviewQuestion(
              avatar: 'S',
              color: Color(0xFF10B981),
              text:
                  '"If you inherited poorly documented legacy code, how would you approach it?"',
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SESSION ANALYSIS — NATASHA F.',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WebStat(
                    value: '87%',
                    label: 'GAZE ON-\nSCREEN',
                    color: const Color(0xFF10B981),
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: _WebStat(
                    value: '74%',
                    label: 'CONFIDENCE\nSCORE',
                    color: AppColors.webRoleHr,
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: _WebStat(
                    value: 'LOW',
                    label: 'CHEATING\nRISK',
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        );
      case 3:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SENIOR DJANGO DEVELOPER — RANKINGS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 14),
            const _WebRankingRow(
              rank: 1,
              name: 'Zohaib A.',
              label: 'STRONG YES',
              color: Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            const _WebRankingRow(
              rank: 2,
              name: 'Umar Z.',
              label: 'YES',
              color: AppColors.webRoleHr,
            ),
            const SizedBox(height: 10),
            const _WebRankingRow(
              rank: 3,
              name: 'Natasha F.',
              label: 'MAYBE',
              color: Color(0xFFF59E0B),
            ),
          ],
        );
    }
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final bool isCurrentPagePoint;
  const _BulletPoint({required this.text, this.isCurrentPagePoint = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: AppColors.webRoleHr.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF81A4FF), size: 13),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: AppColors.webCheckText,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _WebApplicantBar extends StatelessWidget {
  final int score;
  final Color color;
  const _WebApplicantBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.webRoleHr,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: const Color(0xFFE2E8F0),
              color: color,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WebInterviewQuestion extends StatelessWidget {
  final String avatar;
  final Color color;
  final String text;

  const _WebInterviewQuestion({
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            avatar,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _WebStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _WebStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _WebRankingRow extends StatelessWidget {
  final int rank;
  final String name;
  final String label;
  final Color color;

  const _WebRankingRow({
    required this.rank,
    required this.name,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '#$rank',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
