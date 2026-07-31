import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter, AppNavState;

class CandidateReportScreen extends StatefulWidget {
  const CandidateReportScreen({super.key});

  @override
  State<CandidateReportScreen> createState() => _CandidateReportScreenState();
}

class _CandidateReportScreenState extends State<CandidateReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;

  // Search input controller
  final TextEditingController _searchController = TextEditingController();

  // Candidate Data Details
  final double targetScore = 91.0;
  final String candidateName = 'Ayesha Khalid';
  final String roleTitle = 'Senior Django Dev';
  final String date = '13 May';

  // ── STATE VARIABLES FOR RD-03 INTERACTIVITY ──
  // Candidate Decision: null, 'rejected', or 'selected'
  String? _decision;
  bool _isRejectConfirmActive = false;
  bool _isSelectConfirmActive = false;

  // Radar chart highlight state
  String? _hoveredAxis;
  int? _hoveredShapIndex;

  // Playback State
  bool _isPlayingAudio = false;
  double _audioProgress = 0.25;
  String _currentAudioTime = "00:48";
  String _totalAudioTime = "03:12";

  // Search Transcript State
  bool _isSearchOpen = false;
  final TextEditingController _transcriptSearchController =
      TextEditingController();

  // Expanded Transcript Row index
  int? _expandedRowIndex;

  @override
  void initState() {
    super.initState();
    // Configure animation to sweep 0 -> 91 once on mount
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: targetScore).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _transcriptSearchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _transcriptSearchController.dispose();
    super.dispose();
  }

  // Helper to change audio settings when selecting a Q&A row
  void _seekAudioToRow(int index, String totalDuration) {
    setState(() {
      _isPlayingAudio = true;
      _expandedRowIndex = (_expandedRowIndex == index) ? null : index;
      _audioProgress = 0.0;
      _currentAudioTime = "00:00";
      _totalAudioTime = totalDuration;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── BASE GRADIENT ──────────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY ───────────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN CONTENT ───────────────────────────────────────────────────
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // 1. LEFT RAIL (Web Only - Jobs glowing index 1)
                    if (!isMobile) _buildLeftRail(context),

                    // 2. MAIN REPORT CONTENT AREA
                    Expanded(
                      child: Column(
                        children: [
                          // Top Bar
                          _buildTopBar(isMobile),

                          // Scrollable report space
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                20,
                                24,
                                isMobile
                                    ? 130.0
                                    : 20.0, // Extra padding at bottom on mobile for floating actions bar
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isMobile) ...[
                                    // Mobile identity line
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        'AYESHA KHALID · 13 MAY',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],

                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth > 1024) {
                                        return IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Verdict tile (Left)
                                              SizedBox(
                                                width: 320,
                                                child: _buildVerdictTile(
                                                  isMobile: false,
                                                ),
                                              ),
                                              const SizedBox(width: 20),

                                              // Evidence panels fanning out to the right
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        // Score Profile (Radar)
                                                        Expanded(
                                                          child:
                                                              _buildScoreProfileTile(
                                                                isMobile: false,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 20,
                                                        ),

                                                        // What Drove It (SHAP)
                                                        Expanded(
                                                          child: _buildShapTile(
                                                            isMobile: false,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 20),

                                                    // In Plain Language
                                                    Expanded(
                                                      child:
                                                          _buildPlainLanguageTile(
                                                            isMobile: false,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        // Stack vertically on smaller screens/tablets
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _buildVerdictTile(
                                              isMobile: isMobile,
                                            ),
                                            const SizedBox(height: 20),
                                            _buildScoreProfileTile(
                                              isMobile: isMobile,
                                            ),
                                            const SizedBox(height: 20),
                                            _buildShapTile(isMobile: isMobile),
                                            const SizedBox(height: 20),
                                            _buildPlainLanguageTile(
                                              isMobile: isMobile,
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 20),
                                  // Transcript panel (Wide bottom card)
                                  _buildTranscriptTile(isMobile),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isMobile) _buildBottomDock(context),
            ],
          ),

          // Floating Mobile Decision Bar pinned above bottom dock
          if (isMobile) _buildMobileDecisionBar(),
        ],
      ),
    );
  }

  // ── LEFT RAIL NAVIGATION ───────────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Interviews',
        'route': '/schedule',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Rankings',
        'route': '/rankings',
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'route': '/analytics',
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

          // Logo
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
                final isSelected = index == 1; // Jobs stays active
                final item = navItems[index];
                final bool hasBadge =
                    index == 2 && AppNavState.unreadInterviews > 0;

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (isSelected)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardBlue.withOpacity(0.4),
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
                              Navigator.of(
                                context,
                              ).pushReplacementNamed(item['route']);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Icon(
                                  item['icon'],
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasBadge)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: const BoxDecoration(
                              color: AppColors.dashboardRed,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${AppNavState.unreadInterviews}',
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
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

          // User Avatar
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
            ),
            child: Center(
              child: Text(
                'AR',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR (Responsive Breadcrumbs) ───────────────────────────────────────
  Widget _buildTopBar(bool isMobile) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  'Report',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
          // Clickable Breadcrumbs
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    'JOBS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                ' / ',
                style: GoogleFonts.inter(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                candidateName.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                ' / ',
                style: GoogleFonts.inter(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'EVALUATION',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Right Icons (Static layout)
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
                  controller: _searchController,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
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
                      margin: const EdgeInsets.only(
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
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
                badgeColor: AppColors.dashboardRed,
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

  // ── HERO VERDICT TILE (Glowing & Interactive) ──────────────────────────────
  Widget _buildVerdictTile({required bool isMobile}) {
    // Determine dynamic values based on decision
    String badgeLabel = 'STRONG YES';
    Color badgeColor = AppColors.dashboardTeal;

    if (_decision == 'rejected') {
      badgeLabel = 'REJECTED';
      badgeColor = AppColors.dashboardRed;
    } else if (_decision == 'selected') {
      badgeLabel = 'SELECTED';
      badgeColor = const Color(0xFF22C55E);
    }

    final double ringSize = isMobile ? 110.0 : 150.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: badgeColor.withOpacity(0.07),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: Stack(
          children: [
            // Top gradient stripe highlight
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C9BFF),
                      const Color(0xFF8B5CF6),
                      badgeColor,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Sub-header label (Hidden on Mobile)
                  if (!isMobile) ...[
                    Text(
                      '${candidateName.toUpperCase()} · ${roleTitle.toUpperCase()} · ${date.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Verdict Ring
                  AnimatedBuilder(
                    animation: _scoreAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: CustomPaint(
                          painter: VerdictRingPainter(
                            score: _scoreAnimation.value,
                            color: badgeColor,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_scoreAnimation.value.toInt()}',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: const Color(0xFF0F172A),
                                    fontSize: isMobile ? 32 : 42,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  'OF 100',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: isMobile ? 8.5 : 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Verdict Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: badgeColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: GoogleFonts.spaceGrotesk(
                        color: badgeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Rank Text
                  Text(
                    'Ranked #1 of 48 · XGBoost v2.3',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Metrics Chips (GAZE, CONFIDENCE, RISK)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildVerdictMetricWithTooltip(
                        'GAZE',
                        '87%',
                        AppColors.dashboardTeal,
                        'Measures visual attention and focus stability during answers',
                      ),
                      _buildVerdictMetricWithTooltip(
                        'CONFIDENCE',
                        '74%',
                        AppColors.dashboardBlue,
                        'Measures speech delivery confidence and tone analysis',
                      ),
                      _buildVerdictMetricWithTooltip(
                        'RISK',
                        'LOW',
                        const Color(0xFF22C55E),
                        'Measures semantic alignment and behavioral warning flags',
                      ),
                    ],
                  ),

                  // Decision Actions (Web/Desktop View Only)
                  if (!isMobile) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 16),
                    _buildWebDecisionPanel(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictMetricWithTooltip(
    String label,
    String value,
    Color color,
    String explanation,
  ) {
    return Tooltip(
      message: explanation,
      waitDuration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Web decision layout with inline confirmations
  Widget _buildWebDecisionPanel() {
    if (_decision != null) {
      final isSelect = _decision == 'selected';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelect ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelect ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            isSelect
                ? 'Decided: MOVED TO SELECTED'
                : 'Decided: CANDIDATE REJECTED',
            style: GoogleFonts.inter(
              color: isSelect
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_isRejectConfirmActive) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Confirm Reject?',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.dashboardRed,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isRejectConfirmActive = false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _decision = 'rejected';
                _isRejectConfirmActive = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dashboardRed,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    if (_isSelectConfirmActive) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Confirm Select?',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.dashboardBlue,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isSelectConfirmActive = false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _decision = 'selected';
                _isSelectConfirmActive = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dashboardBlue,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Reject Button
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isRejectConfirmActive = true),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'Reject',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Select Button
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isSelectConfirmActive = true),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.dashboardBlue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dashboardBlue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Move to Selected',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── EVIDENCE PANEL 1: SCORE PROFILE (RADAR CHART) ─────────────────────────
  Widget _buildScoreProfileTile({required bool isMobile}) {
    final Map<String, double> radarScores = {
      'RESUME': 91.0,
      'TECH': 84.0,
      'COMMS': 71.0,
      'BEHAV': 78.0,
      'FIT': 88.0,
    };

    final double radarSize = isMobile ? 120.0 : 130.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Score profile',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(label: '5 AXES', color: AppColors.dashboardBlue),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: SizedBox(
                width: radarSize + 60,
                height: radarSize + 40,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Radar Chart Painters
                    SizedBox(
                      width: radarSize,
                      height: radarSize,
                      child: CustomPaint(
                        painter: RadarChartPainter(
                          scores: radarScores,
                          hoveredAxis: _hoveredAxis,
                        ),
                      ),
                    ),

                    // Positioned label overlay (interactivity spoking)
                    // 0: RESUME (Top)
                    _buildRadarPositionedLabel(
                      label: 'RESUME',
                      score: 91,
                      top: -12,
                      left: 0,
                      right: 0,
                      alignment: Alignment.topCenter,
                    ),
                    // 1: TECH (Top Right)
                    _buildRadarPositionedLabel(
                      label: 'TECH',
                      score: 84,
                      top: radarSize * 0.22,
                      right: -24,
                      alignment: Alignment.topRight,
                    ),
                    // 2: COMMS (Bottom Right)
                    _buildRadarPositionedLabel(
                      label: 'COMMS',
                      score: 71,
                      bottom: 0,
                      right: -10,
                      alignment: Alignment.bottomRight,
                    ),
                    // 3: BEHAV (Bottom Left)
                    _buildRadarPositionedLabel(
                      label: 'BEHAV',
                      score: 78,
                      bottom: 0,
                      left: -10,
                      alignment: Alignment.bottomLeft,
                    ),
                    // 4: FIT (Top Left)
                    _buildRadarPositionedLabel(
                      label: 'FIT',
                      score: 88,
                      top: radarSize * 0.22,
                      left: -18,
                      alignment: Alignment.topLeft,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarPositionedLabel({
    required String label,
    required int score,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Alignment alignment,
  }) {
    final bool isHighlighted = _hoveredAxis == label;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Align(
        alignment: alignment,
        child: Tooltip(
          message: '$label evaluation details: $score/100',
          waitDuration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredAxis = label),
            onExit: (_) => setState(() => _hoveredAxis = null),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _hoveredAxis = (_hoveredAxis == label) ? null : label;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? const Color(0xFFEEF2FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isHighlighted
                        ? AppColors.dashboardBlue.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '$label $score',
                  style: GoogleFonts.spaceGrotesk(
                    color: isHighlighted
                        ? AppColors.dashboardBlue
                        : const Color(0xFF64748B),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── EVIDENCE PANEL 2: SHAP GLOW CHART ──────────────────────────────────────
  Widget _buildShapTile({required bool isMobile}) {
    final List<Map<String, dynamic>> shapData = [
      {
        'feature': 'Skills overlap',
        'val': 18,
        'isPositive': true,
        'explanation': '8 of 9 required skills matched in resume and answers',
      },
      {
        'feature': 'Answer depth',
        'val': 12,
        'isPositive': true,
        'explanation': 'Technical answers were detailed and hit core concepts',
      },
      {
        'feature': 'Gaze stability',
        'val': 7,
        'isPositive': true,
        'explanation': 'Maintained steady visual focus during speech analysis',
      },
      {
        'feature': 'Response latency',
        'val': -6,
        'isPositive': false,
        'explanation': 'A few delays when starting technical responses',
      },
      {
        'feature': 'Filler-word rate',
        'val': -9,
        'isPositive': false,
        'explanation': 'Um/ah frequency slightly above cohort median',
      },
    ];

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'What drove it',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(label: 'SHAP', color: AppColors.dashboardBlue),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shapData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = shapData[index];
                final String feature = item['feature'];
                final int val = item['val'];
                final bool isPositive = item['isPositive'];
                final String explanation = item['explanation'];
                final Color color = isPositive
                    ? AppColors.dashboardTeal
                    : AppColors.dashboardRed;

                final bool isHighlighted = _hoveredShapIndex == index;

                return Tooltip(
                  message: explanation,
                  waitDuration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredShapIndex = index),
                    onExit: (_) => setState(() => _hoveredShapIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _hoveredShapIndex = (_hoveredShapIndex == index)
                              ? null
                              : index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? const Color(0xFFF8FAFC)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            // Feature Label
                            SizedBox(
                              width: isMobile ? 85 : 100,
                              child: Text(
                                feature,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            // SHAP Diverging Bar Layout
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  height: 10,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: ShapBarPainter(
                                      value: val,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Value label
                            SizedBox(
                              width: 28,
                              child: Text(
                                isPositive ? '+$val' : '$val',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.spaceGrotesk(
                                  color: color,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── EVIDENCE PANEL 3: PLAIN LANGUAGE ───────────────────────────────────────
  Widget _buildPlainLanguageTile({required bool isMobile}) {
    // Drop plain language to 2 sentences max on mobile
    final String contentText = isMobile
        ? 'Eight of nine required skills matched in Ayesha\'s responses. Technical answers were highly structured, though pace ran slightly long.'
        : 'Eight of nine required skills appear in both the resume and the spoken answers, '
              'and the two Django questions drew concrete, specific examples. Pace was the weak spot '
              '— answers ran long before reaching the point, and filler-word rate sat above the cohort median.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'In plain language',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            contentText,
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── TRANSCRIPT PANEL (Fully Functional) ────────────────────────────────────
  Widget _buildTranscriptTile(bool isMobile) {
    final List<Map<String, dynamic>> transcriptItems = [
      {
        'type': 'B',
        'iconColor': const Color(0xFFEEF2FF),
        'iconTextColor': AppColors.dashboardBlue,
        'question':
            'Tell me about a time you led a difficult project to completion.',
        'details': '03:12 · 412 WORDS',
        'durationOnly': '03:12',
        'score': '8.6',
        'color': AppColors.dashboardTeal,
        'answer':
            'We faced a critical database bottleneck three weeks before release. I led the migration team, coordinated with frontend devs, and we delivered on time with a 40% performance gain.',
      },
      {
        'type': 'T',
        'iconColor': const Color(0xFFE0F2FE),
        'iconTextColor': Colors.lightBlue,
        'question':
            'Walk me through your Django ORM and query-optimisation experience.',
        'details': '04:02 · 588 WORDS',
        'durationOnly': '04:02',
        'score': '8.4',
        'color': AppColors.dashboardTeal,
        'answer':
            'For Django query optimization, I rely heavily on select_related for foreign keys and prefetch_related for many-to-many relationships. I also profile queries using django-debug-toolbar to eliminate N+1 query problems.',
      },
      {
        'type': 'S',
        'iconColor': const Color(0xFFF1F5F9),
        'iconTextColor': const Color(0xFF64748B),
        'question':
            'You inherit poorly documented legacy code. How do you approach it?',
        'details': '02:41 · 301 WORDS',
        'durationOnly': '02:41',
        'score': '7.1',
        'color': AppColors.dashboardBlue,
        'answer':
            'I start by setting up local execution and writing sanity unit tests to map the entry points. Then I run a parser over the file tree and document the core APIs before restructuring any legacy code.',
      },
    ];

    // Filter by transcript search query
    final query = _transcriptSearchController.text.toLowerCase();
    final filteredItems = transcriptItems.where((item) {
      final q = item['question'].toString().toLowerCase();
      final a = item['answer'].toString().toLowerCase();
      return q.contains(query) || a.contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transcript',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              // Action Buttons
              if (isMobile) ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.video_library_rounded,
                        color: AppColors.dashboardBlue,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/review');
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlayingAudio
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        color: const Color(0xFF64748B),
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPlayingAudio = !_isPlayingAudio;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _isSearchOpen
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: const Color(0xFF64748B),
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearchOpen = !_isSearchOpen;
                          if (!_isSearchOpen) {
                            _transcriptSearchController.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacementNamed('/review');
                        },
                        child: Text(
                          'Watch playback · ',
                          style: GoogleFonts.inter(
                            color: AppColors.dashboardBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPlayingAudio = !_isPlayingAudio;
                          });
                        },
                        child: Text(
                          _isPlayingAudio ? 'Pause audio · ' : 'Play audio · ',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (!_isSearchOpen) {
                              _transcriptSearchController.clear();
                            }
                          });
                        },
                        child: Text(
                          _isSearchOpen ? 'Close search ›' : 'Search ›',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // Search Field
          if (_isSearchOpen) ...[
            const SizedBox(height: 10),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _transcriptSearchController,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search inside transcript...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  icon: const Icon(Icons.search, size: 16),
                  isDense: true,
                ),
              ),
            ),
          ],

          // Audio Scrubber Bar
          if (_isPlayingAudio) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.dashboardBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPlayingAudio = false;
                      });
                    },
                    child: const Icon(
                      Icons.pause_circle_filled_rounded,
                      color: AppColors.dashboardBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentAudioTime,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _audioProgress,
                      activeColor: AppColors.dashboardBlue,
                      inactiveColor: const Color(0xFFCBD5E1),
                      onChanged: (val) {
                        setState(() {
                          _audioProgress = val;
                          final totalParts = _totalAudioTime.split(':');
                          final totalSeconds =
                              (int.parse(totalParts[0]) * 60) +
                              int.parse(totalParts[1]);
                          final currentSeconds = (val * totalSeconds).toInt();
                          final minutes = currentSeconds ~/ 60;
                          final seconds = currentSeconds % 60;
                          _currentAudioTime =
                              "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
                        });
                      },
                    ),
                  ),
                  Text(
                    _totalAudioTime,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(color: Color(0xFFF1F5F9), height: 1),
            ),
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              final bool isExpanded = _expandedRowIndex == index;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _seekAudioToRow(index, item['durationOnly']),
                  child: Container(
                    color: isExpanded
                        ? const Color(0xFFF8FAFC)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type Orb
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: item['iconColor'],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  item['type'],
                                  style: GoogleFonts.spaceGrotesk(
                                    color: item['iconTextColor'],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // Question details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['question'],
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF0F172A),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isMobile
                                        ? item['durationOnly']
                                        : item['details'],
                                    style: GoogleFonts.jetBrainsMono(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Question score
                            Text(
                              item['score'],
                              style: GoogleFonts.spaceGrotesk(
                                color: item['color'],
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        // Expanded Answer Text
                        if (isExpanded) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 42),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    item['answer'],
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF334155),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ── MOBILE FLOATING ACTION BAR FOR DECISION ────────────────────────────────
  Widget _buildMobileDecisionBar() {
    return Positioned(
      bottom:
          68 +
          MediaQuery.of(context).padding.bottom, // Pinned above bottom dock
      left: 16,
      right: 16,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: _buildMobileDecisionContent()),
      ),
    );
  }

  Widget _buildMobileDecisionContent() {
    if (_decision != null) {
      final isSelect = _decision == 'selected';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelect ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelect ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5),
            width: 1.2,
          ),
        ),
        child: Text(
          isSelect ? 'Decided: SELECTED' : 'Decided: REJECTED',
          style: GoogleFonts.spaceGrotesk(
            color: isSelect ? const Color(0xFF22C55E) : AppColors.dashboardRed,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (_isRejectConfirmActive) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Confirm Reject?',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.dashboardRed,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _isRejectConfirmActive = false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _decision = 'rejected';
                    _isRejectConfirmActive = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardRed,
                ),
                child: Text(
                  'Confirm',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_isSelectConfirmActive) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Confirm Selection?',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.dashboardBlue,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _isSelectConfirmActive = false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _decision = 'selected';
                    _isSelectConfirmActive = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardBlue,
                ),
                child: Text(
                  'Confirm',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        // Reject
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isRejectConfirmActive = true),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'Reject',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Select
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isSelectConfirmActive = true),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.dashboardBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Select',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MOBILE BOTTOM DOCK ─────────────────────────────────────────────────────
  Widget _buildBottomDock(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Interviews',
        'route': '/schedule',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Rankings',
        'route': '/rankings',
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'route': '/analytics',
      },
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(navItems.length, (index) {
          final isSelected = index == 1; // "Jobs" stays active
          final item = navItems[index];

          return GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacementNamed(item['route']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSelected
                    ? AppColors.dashboardBlue
                    : Colors.transparent,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.dashboardBlue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'],
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    size: 20,
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Text(
                      item['label'],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── CUSTOM PAINTER FOR RADAR CHART ──────────────────────────────────────────
class RadarChartPainter extends CustomPainter {
  final Map<String, double> scores;
  final String? hoveredAxis;
  const RadarChartPainter({required this.scores, this.hoveredAxis});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 10;
    final keys = scores.keys.toList();
    final int axesCount = keys.length;

    // Paints
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fillPaint = Paint()
      ..color = AppColors.dashboardBlue.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = AppColors.dashboardBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pointPaint = Paint()
      ..color = AppColors.dashboardBlue
      ..style = PaintingStyle.fill;

    // Draw concentric 5-sided web grids
    final int gridLevels = 3;
    for (int level = 1; level <= gridLevels; level++) {
      final double currentRadius = radius * (level / gridLevels);
      final gridPath = Path();
      for (int i = 0; i < axesCount; i++) {
        final angle = (i * 2 * math.pi / axesCount) - (math.pi / 2);
        final x = center.dx + currentRadius * math.cos(angle);
        final y = center.dy + currentRadius * math.sin(angle);
        if (i == 0) {
          gridPath.moveTo(x, y);
        } else {
          gridPath.lineTo(x, y);
        }
      }
      gridPath.close();
      canvas.drawPath(gridPath, gridPaint);
    }

    // Draw axis spoke lines from center (highlight hovered spoke)
    for (int i = 0; i < axesCount; i++) {
      final angle = (i * 2 * math.pi / axesCount) - (math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final isHoveredSpoke = keys[i] == hoveredAxis;
      final spokePaint = Paint()
        ..color = isHoveredSpoke
            ? AppColors.dashboardBlue
            : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHoveredSpoke ? 2.5 : 1.0;

      canvas.drawLine(center, Offset(x, y), spokePaint);
    }

    // Compute polygon paths based on candidate scores
    final scorePath = Path();
    final List<Offset> points = [];
    for (int i = 0; i < axesCount; i++) {
      final key = keys[i];
      final double scoreFraction = (scores[key] ?? 0.0) / 100.0;
      final angle = (i * 2 * math.pi / axesCount) - (math.pi / 2);
      final x = center.dx + (radius * scoreFraction) * math.cos(angle);
      final y = center.dy + (radius * scoreFraction) * math.sin(angle);

      points.add(Offset(x, y));
      if (i == 0) {
        scorePath.moveTo(x, y);
      } else {
        scorePath.lineTo(x, y);
      }
    }
    scorePath.close();

    // Fill score polygon
    canvas.drawPath(scorePath, fillPaint);
    // Draw outline border
    canvas.drawPath(scorePath, outlinePaint);

    // Draw tiny circle points at score vertices
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isHoveredPt = keys[i] == hoveredAxis;
      canvas.drawCircle(pt, isHoveredPt ? 5.5 : 3.5, pointPaint);
      canvas.drawCircle(
        pt,
        isHoveredPt ? 2.5 : 1.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.hoveredAxis != hoveredAxis;
  }
}

// ── CUSTOM PAINTER FOR DIVERGING SHAP CHART ─────────────────────────────────
class ShapBarPainter extends CustomPainter {
  final int value;
  final Color color;
  const ShapBarPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final axisPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;

    // Draw central axis line
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );

    // Max hypothetical value for width scaling
    final double maxVal = 24.0;
    final double barWidthFactor = (size.width / 2) * (value.abs() / maxVal);

    // Glow Shadow paint
    final glowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    // Bar paint
    final barPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Rect barRect;
    if (value >= 0) {
      barRect = Rect.fromLTWH(center.dx, 2, barWidthFactor, size.height - 4);
    } else {
      barRect = Rect.fromLTWH(
        center.dx - barWidthFactor,
        2,
        barWidthFactor,
        size.height - 4,
      );
    }

    final rRect = RRect.fromRectAndRadius(barRect, const Radius.circular(3));

    // Draw soft glow first
    canvas.drawRRect(rRect, glowPaint);
    // Draw main colored bar
    canvas.drawRRect(rRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── CUSTOM PAINTER FOR HERO VERDICT SCORE RING ──────────────────────────────
class VerdictRingPainter extends CustomPainter {
  final double score;
  final Color color;
  const VerdictRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Track Background paint
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, bgPaint);

    // Glowing shadow for progress arc
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Active progress arc paint
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100.0) * 2 * math.pi;

    // Draw Glow shadow arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );

    // Draw main progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant VerdictRingPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
