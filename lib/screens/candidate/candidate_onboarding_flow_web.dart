import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import '../signup/candidate_register_screen.dart';

/// Web version of the Candidate Onboarding Flow — 5-page split-panel layout.
class CandidateOnboardingFlowWeb extends StatefulWidget {
  const CandidateOnboardingFlowWeb({super.key});

  @override
  State<CandidateOnboardingFlowWeb> createState() =>
      _CandidateOnboardingFlowWebState();
}

class _CandidateOnboardingFlowWebState
    extends State<CandidateOnboardingFlowWeb> {
  int _currentPage = 0;
  static const int _totalPages = 5;

  // Wave bar heights for the AI interviewer card on page 3
  static const List<double> _waveHeights = [
    16, 28, 40, 52, 44, 60, 48, 56, 36, 44, 52, 32, 20,
  ];

  /// Left-panel data per page — all strings from AppConstants.
  static const List<Map<String, dynamic>> _leftPanelData = [
    {
      'title': AppConstants.candidateWebTitle1,
      'body': AppConstants.candidateWebBody1,
      'highlight': 'actual resume.',
      'points': [
        AppConstants.candidateWebPoint1a,
        AppConstants.candidateWebPoint1b,
        AppConstants.candidateWebPoint1c,
      ],
    },
    {
      'title': AppConstants.candidateWebTitle2,
      'body': AppConstants.candidateWebBody2,
      'highlight': 'person would.',
      'points': [
        AppConstants.candidateWebPoint2a,
        AppConstants.candidateWebPoint2b,
        AppConstants.candidateWebPoint2c,
      ],
    },
    {
      'title': AppConstants.candidateWebTitle3,
      'body': AppConstants.candidateWebBody3,
      'highlight': 'not a form.',
      'points': [
        AppConstants.candidateWebPoint3a,
        AppConstants.candidateWebPoint3b,
        AppConstants.candidateWebPoint3c,
      ],
    },
    {
      'title': AppConstants.candidateWebTitle4,
      'body': AppConstants.candidateWebBody4,
      'highlight': 'in words',
      'points': [
        AppConstants.candidateWebPoint4a,
        AppConstants.candidateWebPoint4b,
        AppConstants.candidateWebPoint4c,
      ],
    },
    {
      'title': AppConstants.candidateWebTitle5,
      'body': AppConstants.candidateWebBody5,
      'highlight': 'on a leash.',
      'points': [
        AppConstants.candidateWebPoint5a,
        AppConstants.candidateWebPoint5b,
        AppConstants.candidateWebPoint5c,
      ],
    },
  ];

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CandidateRegisterScreen()),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CandidateRegisterScreen()),
    );
  }

  // ─── Headline builder: bolds the highlight substring in italic+green ───────
  Widget _buildFormattedHeadline(
    BuildContext context,
    String title,
    String highlight,
  ) {
    final double fs = Responsive.getFontSize(
      context,
      mobile: 26,
      desktop: 32,
    );
    final idx = title.indexOf(highlight);
    if (idx == -1) {
      return Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: fs,
          fontWeight: FontWeight.w800,
          height: 1.22,
          letterSpacing: -0.5,
        ),
      );
    }
    final before = title.substring(0, idx);
    final after = title.substring(idx + highlight.length);
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: fs,
          fontWeight: FontWeight.w800,
          height: 1.22,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: highlight,
            style: GoogleFonts.inter(
              fontSize: fs,
              fontWeight: FontWeight.w800,
              height: 1.22,
              letterSpacing: -0.5,
              fontStyle: FontStyle.italic,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [
                    AppColors.webHeadlineFairlyStart,
                    AppColors.webHeadlineFairlyEnd,
                  ],
                ).createShader(const Rect.fromLTWH(0, 0, 300, 60)),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  // ─── Right panel content switcher ─────────────────────────────────────────
  Widget _buildRightContent() {
    switch (_currentPage) {
      case 0:
        return _buildJobMatchCard();
      case 1:
        return _buildResumeCard();
      case 2:
        return _buildInterviewCard();
      case 3:
        return _buildScoreCard();
      case 4:
        return _buildPrivacyCard();
      default:
        return _buildJobMatchCard();
    }
  }

  Widget _buildJobMatchCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WebJobMatchRow(
            title: 'Senior Django Developer',
            matchScore: 91,
            color: AppColors.candidatePrimary,
          ),
          const SizedBox(height: 24),
          _WebJobMatchRow(
            title: 'Frontend Engineer',
            matchScore: 62,
            color: AppColors.candidatePrimary.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
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
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CV_Muhammad_2026.pdf — Parsed',
                  style: GoogleFonts.inter(
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
            'EXTRACTED SKILLS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.hrTextLight,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CandidateSkillTag(label: 'Django'),
              _CandidateSkillTag(label: 'PostgreSQL'),
              _CandidateSkillTag(label: 'Python'),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.dividerLight),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                color: AppColors.candidatePrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '4.5 yrs experience · BSc Computer Science',
                  style: GoogleFonts.inter(
                    fontSize: 13,
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
    );
  }

  Widget _buildInterviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
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
                  'AI Interviewer — LIVE',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'Q 3 of 8',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.hrTextLight,
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
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.webSubcopy,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your AI score breakdown',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          const _WebScoreRow(
            label: 'Technical skills',
            score: '8.4/10',
            fraction: 0.84,
          ),
          const SizedBox(height: 20),
          const _WebScoreRow(
            label: 'Communication',
            score: '7.1 / 10',
            fraction: 0.71,
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.dividerLight),
          const SizedBox(height: 14),
          Text(
            '"Strong technical depth. Focus on structuring longer answers more concisely."',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Column(
      children: const [
        _CandidatePrivacyRow(text: 'Resume data stays on our servers'),
        SizedBox(height: 12),
        _CandidatePrivacyRow(text: 'Delete your account and data anytime'),
        SizedBox(height: 12),
        _CandidatePrivacyRow(text: 'Scores shared only with your permission'),
      ],
    );
  }

  // ─── Page icon per step ────────────────────────────────────────────────────
  IconData _pageIcon() {
    const icons = [
      Icons.my_location_rounded,
      Icons.manage_search_rounded,
      Icons.mic_rounded,
      Icons.star_outline_rounded,
      Icons.verified_user_outlined,
    ];
    return icons[_currentPage];
  }

  // ─── Page title + subtitle from constants ─────────────────────────────────
  String _rightTitle() {
    const titles = [
      AppConstants.candidateTitle1,
      'Your resume,\nactually read',
      AppConstants.candidateTitle3,
      AppConstants.candidateTitle4,
      AppConstants.candidateTitle5,
    ];
    return titles[_currentPage];
  }

  String _rightSub() {
    const subs = [
      AppConstants.candidateSub1,
      'We split it into sections, pull the skills, and\nshow you exactly what employers match against.',
      AppConstants.candidateSub3,
      AppConstants.candidateSub4,
      AppConstants.candidateSub5,
    ];
    return subs[_currentPage];
  }

  @override
  Widget build(BuildContext context) {
    final currentLeft = _leftPanelData[_currentPage];

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double hPad = Responsive.getSpacing(
            context,
            mobile: 24,
            tablet: 32,
            desktop: 32,
          );
          final double vPad = constraints.maxHeight * 0.05;

          return Stack(
            children: [
              // ── BACKGROUND PANELS ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: dark gradient
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
                        // Radial glow (green tint for candidate)
                        Positioned(
                          top: -300,
                          right: -300,
                          child: Container(
                            width: 800,
                            height: 800,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.candidatePrimary.withValues(
                                    alpha: 0.12,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.8],
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
                  // Right: light green tint background
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF2FBF5),
                    ),
                  ),
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
                      // ── LEFT PANEL ──────────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPad,
                            vertical: vPad,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Brand row — logo from assets
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

                              // Fixed gap — logo to headline
                              SizedBox(height: vPad.clamp(40.0, 72.0)),

                              // Dynamic headline block
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
                                          AppConstants.candidateWebEyebrow,
                                          style: GoogleFonts.inter(
                                            color: AppColors.candidatePrimary
                                                .withValues(alpha: 0.85),
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

                                    // Main headline
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
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              child: _CandidateBulletPoint(
                                                text: e.value,
                                                isActive: e.key == 0,
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

                      // ── RIGHT PANEL ─────────────────────────────────────────
                      Expanded(
                        child: Stack(
                          children: [
                            // Main right content
                            Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: Responsive.rightPanelContentMaxWidth,
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: hPad * 0.6,
                                    vertical: vPad * 1.5,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Column(
                                      key: ValueKey<int>(_currentPage),
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 80),
                                        // "For job seekers" badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: AppColors.candidatePrimary
                                                  .withValues(alpha: 0.5),
                                            ),
                                            color: Colors.transparent,
                                          ),
                                          child: Text(
                                            AppConstants.candidateBadge,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.candidatePrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 28),

                                        // Central icon box
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: AppColors.candidateLightGreen,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Icon(
                                            _pageIcon(),
                                            color: AppColors.candidatePrimary,
                                            size: 34,
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        // Right-panel title
                                        Text(
                                          _rightTitle(),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.hrTextDark,
                                            height: 1.25,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Right-panel subtitle
                                        Text(
                                          _rightSub(),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.hrTextGrey,
                                            height: 1.55,
                                          ),
                                        ),
                                        const SizedBox(height: 28),

                                        // Page-specific card/widget
                                        _buildRightContent(),
                                        const SizedBox(height: 28),

                                        // Pagination dots
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            _totalPages,
                                            (i) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                width: _currentPage == i
                                                    ? 24
                                                    : 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: _currentPage == i
                                                      ? AppColors.candidatePrimary
                                                      : AppColors
                                                          .candidateDotInactive,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Next / Create account button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: ElevatedButton(
                                            onPressed: _nextPage,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.candidatePrimary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                            ),
                                            child: Text(
                                              _currentPage == _totalPages - 1
                                                  ? AppConstants
                                                      .candidateCreateAccount
                                                  : AppConstants
                                                      .candidateNextButton,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
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

                            // Skip button
                            Positioned(
                              top: vPad,
                              right: hPad,
                              child: TextButton(
                                onPressed: _skip,
                                child: Text(
                                  'Skip',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.candidatePrimary,
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CandidateBulletPoint extends StatelessWidget {
  final String text;
  final bool isActive;
  const _CandidateBulletPoint({required this.text, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.candidatePrimary
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: isActive
                  ? AppColors.candidatePrimary
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: isActive
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _WebJobMatchRow extends StatelessWidget {
  final String title;
  final int matchScore;
  final Color color;
  const _WebJobMatchRow({
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
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '$matchScore%',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.candidateProgressBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: matchScore / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateSkillTag extends StatelessWidget {
  final String label;
  const _CandidateSkillTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.candidateLightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.candidatePrimary,
        ),
      ),
    );
  }
}

class _WebScoreRow extends StatelessWidget {
  final String label;
  final String score;
  final double fraction;
  const _WebScoreRow({
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
              style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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

class _CandidatePrivacyRow extends StatelessWidget {
  final String text;
  const _CandidatePrivacyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.candidatePrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
