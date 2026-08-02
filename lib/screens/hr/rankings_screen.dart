import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Selected filter on mobile
  String _selectedFilter = 'All';

  // Full cohort candidates
  final List<Map<String, dynamic>> _cohort = [
    {
      'rank': 1,
      'initials': 'AK',
      'name': 'Ayesha Khalid',
      'driver': 'Django ORM depth',
      't': 8.4,
      'b': 8.6,
      'c': 7.9,
      'score': 91,
      'badge': 'STRONG YES',
      'badgeColor': AppColors.dashboardTeal,
      'selected': false,
      'avatarBg': const Color(0xFFEFF6FF),
    },
    {
      'rank': 2,
      'initials': 'BM',
      'name': 'Bilal Mahmood',
      'driver': 'Async Celery tasks',
      't': 8.1,
      'b': 7.2,
      'c': 7.6,
      'score': 84,
      'badge': 'YES',
      'badgeColor': AppColors.dashboardBlue,
      'selected': false,
      'avatarBg': const Color(0xFFECFDF5),
    },
    {
      'rank': 3,
      'initials': 'NU',
      'name': 'Natasha Usman',
      'driver': 'DRF serialization tuning',
      't': 7.0,
      'b': 7.4,
      'c': 6.8,
      'score': 73,
      'badge': 'YES',
      'badgeColor': AppColors.dashboardBlue,
      'selected': false,
      'avatarBg': const Color(0xFFF5F3FF),
    },
    {
      'rank': 4,
      'initials': 'ZF',
      'name': 'Zara Fatima',
      'driver': 'Database locking details',
      't': 6.6,
      'b': 6.9,
      'c': 6.1,
      'score': 67,
      'badge': 'MAYBE',
      'badgeColor': AppColors.dashboardAmber,
      'selected': false,
      'avatarBg': const Color(0xFFFFFBEB),
    },
    {
      'rank': 5,
      'initials': 'HA',
      'name': 'Hassan Ali',
      'driver': 'Celery memory troubleshooting',
      't': 4.1,
      'b': 4.8,
      'c': 3.9,
      'score': 38,
      'badge': 'NO',
      'badgeColor': AppColors.dashboardRed,
      'selected': false,
      'avatarBg': const Color(0xFFFEF2F2),
    },
  ];

  bool _showCompareModal = false;

  int get _selectedCount => _cohort.where((c) => c['selected'] == true).length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelect(int index) {
    setState(() {
      _cohort[index]['selected'] = !_cohort[index]['selected'];
    });
  }

  List<Map<String, dynamic>> _getFilteredCohort() {
    if (_selectedFilter == 'All') return _cohort;
    return _cohort.where((c) => c['badge'].toLowerCase() == _selectedFilter.toLowerCase()).toList();
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

          // ── GRID PATTERN OVERLAY (Web Only) ─────────────────────────────────
          if (!isMobile) Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN WORKSPACE CONTENT ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 1. LEFT RAIL (Web Only)
                if (!isMobile) _buildLeftRail(context),

                // 2. MAIN WORKSPACE
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar (Web Only)
                      if (!isMobile) _buildTopBar(),

                      // Mobile Header (Mobile Only)
                      if (isMobile) _buildMobileHeader(),

                      // Scrollable rankings content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 12 : 8,
                          ),
                          child: isMobile ? _buildMobileLayout() : _buildWebLayout(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── PERSISTENT COMPARE BUTTON (Web & Mobile) ────────────────────────
          if (_selectedCount >= 2)
            Positioned(
              bottom: isMobile ? 96 : 32, // clear bottom docks
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 320,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () {
                        setState(() {
                          _showCompareModal = true;
                        });
                      },
                      child: Center(
                        child: Text(
                          'Compare selected ($_selectedCount)',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── MOBILE FLOATING BOTTOM DOCK ────────────────────────────────────
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),

          // ── COMPARISON REPORT MODAL OVERLAY ────────────────────────────────
          if (_showCompareModal) _buildCompareOverlay(),
        ],
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderArea(),
        _buildPodiumLayout(),
        const SizedBox(height: 24),
        _buildCohortTableCard(isMobile: false),
        const SizedBox(height: 100),
      ],
    );
  }

  // ── MOBILE LAYOUT (Single List + Filter Chips, No Podium) ──────────────────
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Row
        _buildMobileFilterChips(),
        const SizedBox(height: 16),

        // Scrollable ranked candidates list card
        _buildCohortTableCard(isMobile: true),
        const SizedBox(height: 160), // Space for floating comparison bar + dock
      ],
    );
  }

  // ── MOBILE FILTER CHIPS ────────────────────────────────────────────────────
  Widget _buildMobileFilterChips() {
    final filters = ['All', 'Strong Yes', 'Yes', 'Maybe'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final filter = filters[idx];
          final isSelected = _selectedFilter == filter;

          return ChoiceChip(
            label: Text(
              filter,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: isSelected,
            onSelected: (val) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            selectedColor: AppColors.dashboardBlue,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.dashboardBlue : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  // ── MOBILE APP HEADER ──────────────────────────────────────────────────────
  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/images/logo.svg', height: 26),
              const SizedBox(width: 10),
              Text(
                'Rankings',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            'XGBoost v2.3',
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── WEB HEADER AREA ────────────────────────────────────────────────────────
  Widget _buildHeaderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rankings — Senior Django Developer',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Interviewed cohort · XGBoost v2.3 · $_selectedCount selected for comparison',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── WEB PODIUM GRID ────────────────────────────────────────────────────────
  Widget _buildPodiumLayout() {
    // 2nd place on left, 1st place in middle (taller), 3rd place on right
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          Expanded(
            child: _buildPodiumTile(_cohort[1], height: 160, isHot: false),
          ),
          const SizedBox(width: 16),
          // 1st Place (taller, glowing orb card)
          Expanded(
            child: _buildPodiumTile(_cohort[0], height: 190, isHot: true),
          ),
          const SizedBox(width: 16),
          // 3rd Place
          Expanded(
            child: _buildPodiumTile(_cohort[2], height: 140, isHot: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumTile(Map<String, dynamic> candidate, {required double height, required bool isHot}) {
    final int rank = candidate['rank'];
    final String name = candidate['name'];
    final String driver = candidate['driver'];
    final double t = candidate['t'];
    final double b = candidate['b'];
    final double c = candidate['c'];
    final int score = candidate['score'];
    final int index = _cohort.indexOf(candidate);

    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHot ? AppColors.dashboardTeal : const Color(0xFFE2E8F0),
          width: isHot ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          if (isHot)
            BoxShadow(
              color: AppColors.dashboardTeal.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Large Monospace Rank Numeral
              Text(
                '#$rank',
                style: GoogleFonts.jetBrainsMono(
                  color: isHot ? AppColors.dashboardTeal : const Color(0xFF94A3B8),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              // Compare Checkbox
              Checkbox(
                value: candidate['selected'],
                activeColor: AppColors.dashboardBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) => _toggleSelect(index),
              ),
            ],
          ),

          // Name and SHAP Driver line
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Strongest driver: $driver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Stats & score ring row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'T $t · B $b · C $c',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // Score Ring (36px diameter)
              SizedBox(
                width: 34,
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100.0,
                      strokeWidth: 3.5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isHot ? AppColors.dashboardTeal : AppColors.dashboardBlue,
                      ),
                    ),
                    Text(
                      '$score',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CANDIDATE LIST CARD ────────────────────────────────────────────────────
  Widget _buildCohortTableCard({required bool isMobile}) {
    final candidatesList = isMobile ? _getFilteredCohort() : _cohort;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ranked Candidates',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isMobile)
                  Text(
                    'T · B · C · SCORE',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: candidatesList.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
            itemBuilder: (context, idx) {
              final cand = candidatesList[idx];
              final int rank = cand['rank'];
              final String name = cand['name'];
              final String driver = cand['driver'];
              final double t = cand['t'];
              final double b = cand['b'];
              final double c = cand['c'];
              final int score = cand['score'];
              final String badge = cand['badge'];
              final Color badgeColor = cand['badgeColor'];
              final bool isSelected = cand['selected'];
              final Color avatarBg = cand['avatarBg'];
              final int originalIndex = _cohort.indexOf(cand);

              // Candidate #1 glow effect rule (both web and mobile list views)
              final bool isTopGlow = rank == 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isTopGlow ? AppColors.dashboardTeal.withValues(alpha: 0.02) : Colors.transparent,
                  boxShadow: isTopGlow
                      ? [
                          BoxShadow(
                            color: AppColors.dashboardTeal.withValues(alpha: 0.04),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    // Monospace Rank Numeral (24px)
                    SizedBox(
                      width: 32,
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.jetBrainsMono(
                          color: isTopGlow ? AppColors.dashboardTeal : const Color(0xFF94A3B8),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    // Compare Checkbox
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.dashboardBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) => _toggleSelect(originalIndex),
                    ),
                    const SizedBox(width: 6),

                    // Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          cand['initials'],
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF334155),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + SHAP Driver Metadata line
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Strongest driver: $driver',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Stats T B C (Web Only)
                    if (!isMobile) ...[
                      _buildStatText(t.toStringAsFixed(1)),
                      const SizedBox(width: 16),
                      _buildStatText(b.toStringAsFixed(1)),
                      const SizedBox(width: 16),
                      _buildStatText(c.toStringAsFixed(1)),
                      const SizedBox(width: 20),
                    ],

                    // Score Ring (32px diameter)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: score / 100.0,
                            strokeWidth: 3.2,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                          ),
                          Text(
                            '$score',
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF0F172A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Recommendation Badge
                    _buildRecommendationBadge(label: badge, color: badgeColor),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatText(String val) {
    return SizedBox(
      width: 24,
      child: Text(
        val,
        textAlign: TextAlign.right,
        style: GoogleFonts.jetBrainsMono(
          color: const Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRecommendationBadge({required String label, required Color color}) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── SIDE-BY-SIDE DR-03 COMPARE PANEL ───────────────────────────────────────
  Widget _buildCompareOverlay() {
    final selectedCandidates = _cohort.where((c) => c['selected'] == true).toList();

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F172A).withValues(alpha: 0.3),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 580,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Candidate Comparison',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () {
                        setState(() {
                          _showCompareModal = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Side-by-side technical, behavioral, and confidence scores breakdown.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 28),

                Expanded(
                  child: Row(
                    children: [
                      for (int i = 0; i < selectedCandidates.length.clamp(0, 2); i++) ...[
                        if (i > 0) const SizedBox(width: 20),
                        Expanded(
                          child: _buildComparisonScorecard(selectedCandidates[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          _showCompareModal = false;
                        });
                      },
                      child: Text(
                        'Close Comparison',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonScorecard(Map<String, dynamic> candidate) {
    final String name = candidate['name'];
    final String driver = candidate['driver'];
    final double t = candidate['t'];
    final double b = candidate['b'];
    final double c = candidate['c'];
    final int score = candidate['score'];
    final Color color = candidate['badgeColor'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: candidate['avatarBg'],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    candidate['initials'],
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF334155),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 5,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Text(
                    '$score',
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildComparisonMetricRow('Technical', t, Colors.blue),
          const SizedBox(height: 12),
          _buildComparisonMetricRow('Behavioral', b, AppColors.dashboardTeal),
          const SizedBox(height: 12),
          _buildComparisonMetricRow('Confidence', c, AppColors.dashboardAmber),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),

          Text(
            'KEY REASONING DRIVER',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'XGBoost model identified $driver as the primary positive performance signal for this candidate.',
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonMetricRow(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / 10.0,
            minHeight: 4,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── WEB LEFT RAIL NAVIGATION ───────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Interviews', 'route': '/schedule'},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'route': '/rankings'},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'route': '/analytics'},
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'route': '/settings'},
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
                final isSelected = index == 3; // Rankings is active/selected (index 3)
                final item = navItems[index];
                final bool hasBadge = index == 1; // Jobs has unread item badge "18"

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
                            color: AppColors.dashboardBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardBlue.withValues(alpha: 0.4),
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
                              if (!isSelected) {
                                Navigator.of(context).pushReplacementNamed(item['route']);
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
                                child: Icon(
                                  item['icon'],
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge Sit on Top-Right Corner
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardBlue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              '18',
                              style: TextStyle(
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

          // Avatar bottom
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

  // ── WEB TOP BAR ────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
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
          // Breadcrumbs
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    'RANKINGS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
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
                'SENIOR DJANGO DEV',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Actions Search/Notifications
          Row(
            children: [
              // Search Input
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

              // Notification button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardRed,
              ),
              const SizedBox(width: 10),

              // Language button
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

  // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMobileDockItem(Icons.dashboard_rounded, '/dashboard', false),
          _buildMobileDockItem(Icons.menu_book_rounded, '/pipeline', false),
          _buildMobileDockItem(Icons.calendar_month_rounded, '/schedule', false),
          _buildMobileDockItem(Icons.emoji_events_outlined, '/rankings', true), // active
          _buildMobileDockItem(Icons.analytics_outlined, '/analytics', false),
        ],
      ),
    );
  }

  Widget _buildMobileDockItem(IconData icon, String route, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.dashboardBlue : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF94A3B8),
          size: 22,
        ),
      ),
    );
  }
}
