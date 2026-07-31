import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';

class CandidateFeedbackReportScreen extends StatefulWidget {
  const CandidateFeedbackReportScreen({super.key});

  @override
  State<CandidateFeedbackReportScreen> createState() => _CandidateFeedbackReportScreenState();
}

class _CandidateFeedbackReportScreenState extends State<CandidateFeedbackReportScreen> with SingleTickerProviderStateMixin {
  final int _activeNavIndex = 3; // Interviews is index 3
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;

  // Expanding items indices
  int _expandedWorkedIndex = -1;
  int _expandedWorkOnIndex = -1;
  int _expandedQuestionIndex = -1;

  final List<Map<String, String>> _workedItems = [
    {
      'title': 'Concrete examples in every technical answer',
      'detail': 'You referenced your work on the inventory management system and the migration from Django 2.2 to 3.2 — both directly relevant to the role.'
    },
    {
      'title': 'Steady eye contact and pacing after Q2',
      'detail': 'Your speech rate settled to a steady 130 words per minute, allowing the proctor AI to transcribe technical terminology with high confidence.'
    },
    {
      'title': 'Clear trade-off reasoning on the Celery question',
      'detail': 'You correctly identified queue overhead, serialization options, and task monitoring tools (Flower) compared to lightweight database solutions.'
    }
  ];

  final List<Map<String, String>> _workOnItems = [
    {
      'title': 'Answers ran long — lead with the conclusion',
      'cohort': 'Avg 3m 40s vs 2m 30s cohort',
      'detail': 'Try the STAR method: Situation → Task → Action → Result. State the result first, then back into the context to keep responses focused.'
    },
    {
      'title': 'Filler words above median in Q1–Q2',
      'cohort': 'Settled once warmed up',
      'detail': 'Pause silently instead of using vocal fillers like "um" or "like" while planning your database indexing arguments.'
    }
  ];

  final List<Map<String, dynamic>> _questions = [
    {
      'type': 'T',
      'title': 'Django ORM & query optimisation',
      'score': 84,
      'color': const Color(0xFF10B981),
      'why': 'Strong details on select_related and prefetch_related, but could have mentioned query caching strategies.'
    },
    {
      'type': 'B',
      'title': 'Leading a difficult project',
      'score': 79,
      'color': const Color(0xFF3B82F6),
      'why': 'Demonstrated clear ownership and prioritization under deadlines, though impact metrics could be more quantified.'
    },
    {
      'type': 'S',
      'title': 'Legacy code approach',
      'score': 66,
      'color': const Color(0xFFF59E0B),
      'why': 'Solid safe refactoring outline; however, lacked detail on regression test coverage criteria.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: 76).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    final Color bgBase = const Color(0xFFF8FAFC);
    final Color textPrimary = const Color(0xFF0F172A);
    final Color textSecondary = const Color(0xFF64748B);
    final Color cardBg = Colors.white;
    final Color cardBorder = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // Grid Painter Background
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // Teal Aurora Glow
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 300 : 450,
              height: isMobile ? 300 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(alpha: isMobile ? 0.06 : 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Content Wrapper
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left Rail (Web Only)
                      if (!isMobile) _buildLeftRail(context),

                      // Main Canvas
                      Expanded(
                        child: Column(
                          children: [
                            _buildTopBar(isMobile, textPrimary, textSecondary, cardBg, cardBorder),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 24,
                                  right: isMobile ? 16 : 24,
                                  top: 16,
                                  bottom: isMobile ? 100 : 32,
                                ),
                                child: isMobile
                                    ? _buildMobileLayout(textPrimary, textSecondary, cardBg, cardBorder)
                                    : _buildWebLayout(textPrimary, textSecondary, cardBg, cardBorder),
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
          ),

          // Bottom Navigation Dock (Mobile Only)
          if (isMobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Hero Ring + Summary) - 1.15fr
            Expanded(
              flex: 115,
              child: _buildHeroScoreCard(textPrimary, textSecondary, cardBg, cardBorder, false),
            ),
            const SizedBox(width: 24),

            // Right Columns (Worked + Work On) - 1fr each
            Expanded(
              flex: 100,
              child: _buildWorkedPanel(textPrimary, textSecondary, cardBg, cardBorder),
            ),
            const SizedBox(width: 24),

            Expanded(
              flex: 100,
              child: _buildWorkOnPanel(textPrimary, textSecondary, cardBg, cardBorder),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Bottom Row: Question by Question
        _buildQuestionsListPanel(textPrimary, textSecondary, cardBg, cardBorder, false),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Column(
      children: [
        _buildHeroScoreCard(textPrimary, textSecondary, cardBg, cardBorder, true),
        const SizedBox(height: 16),
        _buildWorkedPanel(textPrimary, textSecondary, cardBg, cardBorder),
        const SizedBox(height: 16),
        _buildWorkOnPanel(textPrimary, textSecondary, cardBg, cardBorder),
        const SizedBox(height: 16),
        _buildQuestionsListPanel(textPrimary, textSecondary, cardBg, cardBorder, true),
      ],
    );
  }

  // ── LEFT COLUMN HERO CARD ──────────────────────────────────────────────────
  Widget _buildHeroScoreCard(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    final double ringSize = isMobile ? 116 : 140;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isMobile ? 'YOUR INTERVIEW · 13 MAY' : 'YOUR INTERVIEW · SENIOR DJANGO DEV · 13 MAY',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.dashboardTeal,
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 20),

          // Animated score ring
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              final double value = _scoreAnimation.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: CircularProgressIndicator(
                      value: value / 100,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.dashboardTeal),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${value.toInt()}%',
                        style: GoogleFonts.spaceGrotesk(
                          color: textPrimary,
                          fontSize: isMobile ? 28 : 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'OVERALL',
                        style: GoogleFonts.spaceGrotesk(
                          color: textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          Text(
            'Strong technical depth, steady presence',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Better than 68% of candidates who interviewed for similar roles this month.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 18),

          // Sub metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSubMetric('TECHNICAL', '8.2', AppColors.dashboardTeal),
              _buildSubMetric('COMMS', '7.0', AppColors.dashboardBlue),
              _buildSubMetric('CONFIDENCE', '7.4', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── WHAT WORKED PANEL ──────────────────────────────────────────────────────
  Widget _buildWorkedPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What worked',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          Column(
            children: List.generate(_workedItems.length, (index) {
              final item = _workedItems[index];
              final isExpanded = _expandedWorkedIndex == index;

              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 16,
                    leading: const Text(
                      '▲',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                    ),
                    title: Text(
                      item['title']!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF334155),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _expandedWorkedIndex = isExpanded ? -1 : index;
                      });
                    },
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 20, bottom: 12),
                      child: Text(
                        item['detail']!,
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  if (index < _workedItems.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── WORK ON NEXT PANEL ─────────────────────────────────────────────────────
  Widget _buildWorkOnPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                'Work on next',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'COACHING',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFFD97706),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Column(
            children: List.generate(_workOnItems.length, (index) {
              final item = _workOnItems[index];
              final isExpanded = _expandedWorkOnIndex == index;

              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minLeadingWidth: 16,
                    leading: const Text(
                      '◆',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF334155),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['cohort']!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD97706),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _expandedWorkOnIndex = isExpanded ? -1 : index;
                      });
                    },
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 20, bottom: 12),
                      child: Text(
                        item['detail']!,
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  if (index < _workOnItems.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── QUESTION BY QUESTION PANEL ─────────────────────────────────────────────
  Widget _buildQuestionsListPanel(
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question by question',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Column(
            children: List.generate(_questions.length, (index) {
              final q = _questions[index];
              final isExpanded = _expandedQuestionIndex == index;
              final double ringSize = isMobile ? 34 : 36;

              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: q['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          q['type'],
                          style: GoogleFonts.jetBrainsMono(
                            color: q['color'],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      q['title'],
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: CircularProgressIndicator(
                            value: q['score'] / 100,
                            strokeWidth: 3,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(q['color']),
                          ),
                        ),
                        Text(
                          '${q['score']}',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF0F172A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _expandedQuestionIndex = isExpanded ? -1 : index;
                      });
                    },
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 38, bottom: 16, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why this score:',
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF0F172A),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            q['why'],
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF334155),
                              elevation: 0,
                              minimumSize: const Size(120, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF0F172A),
                                  content: Text(
                                    'Playing simulated voice response...',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: Text(
                              'Play recording',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  if (index < _questions.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home_rounded, 'label': 'Home', 'route': '/candidate/home'},
      {
        'icon': Icons.track_changes_rounded,
        'label': 'Applications',
        'route': '/candidate/applications',
      },
      {
        'icon': Icons.grid_view_rounded,
        'label': 'Jobs',
        'route': '/candidate/jobs',
      },
      {
        'icon': Icons.radio_button_checked_rounded,
        'label': 'Interviews',
        'route': '/candidate/interviews',
      },
      {
        'icon': Icons.adjust_rounded,
        'label': 'Settings',
        'route': '/candidate/settings',
      },
    ];

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
              child: SvgPicture.asset('assets/images/logo.svg', height: 48),
            ),
          ),
          const SizedBox(height: 40),

          // Nav Items
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final isSelected = index == _activeNavIndex;
                final item = navItems[index];
                final bool hasBadge = index == 2 || index == 3;
                final String badgeVal = index == 2 ? "3" : "1";

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Active glowing orb
                      if (isSelected)
                        Container(
                          width: 42,
                           height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardTeal,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardTeal.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                      Tooltip(
                        message: item['label'],
                        waitDuration: const Duration(milliseconds: 350),
                        preferBelow: false,
                        verticalOffset: 24,
                        margin: const EdgeInsets.only(left: 45),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (index == 0) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                                );
                              } else if (index == 1) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                                );
                              } else if (index == 2) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateJobFeedScreen()),
                                );
                              } else if (index == 3) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const CandidateInterviewLobbyScreen()),
                                );
                              } else {
                                _showMockNavigation(item['route']);
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Child seam indicator inside Interviews tab
                                      if (isSelected)
                                        Container(
                                          width: 3,
                                          height: 12,
                                          margin: const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(1),
                                          ),
                                        ),
                                      Icon(
                                        item['icon'],
                                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        size: 19,
                                      ),
                                    ],
                                  ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardTeal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              badgeVal,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Role Switcher
          PopupMenuButton<String>(
            tooltip: 'Switch Workspace Role',
            onSelected: (value) {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'candidate_home') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                );
              } else if (value == 'candidate_apps') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recruiter',
                child: Text('Recruiter Workspace', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: 'candidate_home',
                child: Text('Candidate Home', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: 'candidate_apps',
                child: Text('Candidate Applications', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6F7F5),
                border: Border.all(color: const Color(0xFF32BAB1).withValues(alpha: 0.3), width: 1),
              ),
              child: Center(
                child: Text(
                  'MR',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF32BAB1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'route': '/candidate/home'},
      {'icon': Icons.track_changes_rounded, 'route': '/candidate/applications'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/jobs'},
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/candidate/interviews',
      },
      {'icon': Icons.adjust_rounded, 'route': '/candidate/settings'},
    ];

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(dockItems.length, (index) {
          final isSelected = index == _activeNavIndex;
          final item = dockItems[index];
          final bool hasBadge = index == 2 || index == 3;
          final String badgeVal = index == 2 ? "3" : "1";

          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                );
              } else if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateApplicationsScreen()),
                );
              } else if (index == 2) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateJobFeedScreen()),
                );
              } else if (index == 3) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateInterviewLobbyScreen()),
                );
              } else {
                _showMockNavigation(item['route']);
              }
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.dashboardTeal : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.dashboardTeal.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Child seam indicator inside mobile Interviews tab
                      if (isSelected)
                        Container(
                          width: 2.5,
                          height: 10,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      Icon(
                        item['icon'],
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                      ),
                      child: Text(
                        badgeVal,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── TOP BAR (Web & Mobile) ──────────────────────────────────────────────────
  Widget _buildTopBar(
    bool isMobile,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                    );
                  },
                ),
                Text(
                  'Feedback',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.search_rounded, color: textSecondary, size: 22),
              onPressed: () => _showMockNavigation('/search'),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs: INTERVIEWS / 13 MAY / FEEDBACK
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'INTERVIEWS',
                    style: GoogleFonts.spaceGrotesk(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                '  /  ',
                style: GoogleFonts.spaceGrotesk(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '13 MAY',
                style: GoogleFonts.spaceGrotesk(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '  /  ',
                style: GoogleFonts.spaceGrotesk(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'FEEDBACK',
                style: GoogleFonts.spaceGrotesk(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
              ),
              const SizedBox(width: 10),

              _buildTopBarIconButton(
                icon: Icons.language_rounded,
                hasBadge: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required bool hasBadge,
    Color? badgeColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: const Color(0xFF475569), size: 18),
          if (hasBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMockNavigation(String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Navigating to: $destination',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
