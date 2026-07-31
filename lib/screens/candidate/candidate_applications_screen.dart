import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_job_feed_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_feedback_report_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_interview_history_screen.dart';
import 'candidate_profile_settings_screen.dart';

class CandidateApplicationsScreen extends StatefulWidget {
  const CandidateApplicationsScreen({super.key});

  @override
  State<CandidateApplicationsScreen> createState() =>
      _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState
    extends State<CandidateApplicationsScreen> {
  final int _activeNavIndex = 1; // Applications is index 1

  // Filter tabs: 'Active', 'Offers', 'Closed'
  String _selectedFilter = 'Active';

  // Inline Offer expansion states
  bool _isOfferExpanded = false;
  String _offerStatus = 'PENDING'; // 'PENDING', 'ACCEPTED', 'DECLINED'

  // Search input control
  final TextEditingController _searchController = TextEditingController();

  // Mock application data
  final List<Map<String, dynamic>> _applications = [
    {
      'role': 'Senior Django Dev',
      'company': 'TechVerse',
      'stage': 'INTERVIEW',
      'detail': 'Interview Wed 13:00',
      'time': 'Interview scheduled',
      'step': 3, // APPLIED(1) -> SCREENED(2) -> INTERVIEW(3) -> DECISION(4)
      'filter': 'Active',
    },
    {
      'role': 'ML Engineer',
      'company': 'NeuralTech',
      'stage': 'OFFER',
      'detail': 'Offer received',
      'time': 'Action required',
      'step': 4,
      'filter': 'Offers', // also fits Active
    },
    {
      'role': 'Full Stack Dev',
      'company': 'CodeCraft',
      'stage': 'IN REVIEW',
      'detail': 'Screening in progress',
      'time': 'Under review',
      'step': 2,
      'filter': 'Active',
    },
    {
      'role': 'Backend Eng',
      'company': 'DataFlow',
      'stage': 'APPLIED',
      'detail': 'Applied 2d ago',
      'time': 'Applied 2 days ago',
      'step': 1,
      'filter': 'Active',
    },
    {
      'role': 'iOS Developer',
      'company': 'AppStudio',
      'stage': 'CLOSED',
      'detail': 'Position filled',
      'time': 'Closed 1 week ago',
      'step': 4,
      'filter': 'Closed',
    },
    {
      'role': 'Data Scientist',
      'company': 'InfoCorp',
      'stage': 'CLOSED',
      'detail': 'Application withdrawn',
      'time': 'Closed 2 weeks ago',
      'step': 2,
      'filter': 'Closed',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get matching filtered applications
  List<Map<String, dynamic>> _getFilteredApps() {
    return _applications.where((app) {
      final filter = app['filter'];
      if (_selectedFilter == 'Offers') {
        return filter == 'Offers' || app['stage'] == 'OFFER';
      }
      if (_selectedFilter == 'Closed') {
        return filter == 'Closed';
      }
      // 'Active' contains all except closed
      return filter == 'Active' || filter == 'Offers';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    // Both Web and Mobile viewport are Light Theme
    final Color bgBase = const Color(0xFFF8FAFC);
    final Color textPrimary = const Color(0xFF0F172A);
    final Color textSecondary = const Color(0xFF64748B);
    final Color cardBg = Colors.white;
    final Color cardBorder = const Color(0xFFE2E8F0);

    final filteredApps = _getFilteredApps();

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          // ── GRID PATTERN OVERLAY ───────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.black.withValues(alpha: 0.015),
              ),
            ),
          ),

          // ── SOFT TEAL AURORA GLOW ──────────────────────────────────────────
          Positioned(
            top: isMobile ? -50 : -120,
            left: isMobile ? 20 : 180,
            child: Container(
              width: isMobile ? 300 : 450,
              height: isMobile ? 300 : 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashboardTeal.withValues(
                  alpha: isMobile ? 0.06 : 0.04,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── LAYOUT ROOT ────────────────────────────────────────────────────
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
                            _buildTopBar(
                              isMobile,
                              textPrimary,
                              textSecondary,
                              cardBg,
                              cardBorder,
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: isMobile ? 16 : 24,
                                  right: isMobile ? 16 : 24,
                                  top: 16,
                                  bottom: isMobile
                                      ? 100
                                      : 32, // bottom margin for mobile dock
                                ),
                                child: _buildContentCanvas(
                                  isMobile,
                                  filteredApps,
                                  textPrimary,
                                  textSecondary,
                                  cardBg,
                                  cardBorder,
                                ),
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

          // ── BOTTOM DOCK NAV (Mobile Only) ──────────────────────────────────
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

  // ── CONTENT CANVAS ─────────────────────────────────────────────────────────
  Widget _buildContentCanvas(
    bool isMobile,
    List<Map<String, dynamic>> filteredApps,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title / Summary row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Applications',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '6 active · 2 closed',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Tabs (Web Only - fixed pill tabs)
            if (!isMobile) _buildFilterTabsWeb(),
          ],
        ),
        const SizedBox(height: 16),

        // Tabs (Mobile Only - horizontal chip row)
        if (isMobile) ...[
          _buildFilterChipsMobile(cardBorder),
          const SizedBox(height: 16),
        ],

        // Application rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredApps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, idx) {
            final app = filteredApps[idx];
            return _buildApplicationRow(
              isMobile,
              app,
              textPrimary,
              textSecondary,
              cardBg,
              cardBorder,
            );
          },
        ),
      ],
    );
  }

  // ── FILTER TABS (Web) ──────────────────────────────────────────────────────
  Widget _buildFilterTabsWeb() {
    final tabs = ['Active', 'Offers', 'Closed'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedFilter == tab;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = tab;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                tab == 'Active'
                    ? 'Active 6'
                    : (tab == 'Offers' ? 'Offers 1' : 'Closed 2'),
                style: GoogleFonts.inter(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── FILTER CHIPS (Mobile) ──────────────────────────────────────────────────
  Widget _buildFilterChipsMobile(Color cardBorder) {
    final tabs = ['Active', 'Offers', 'Closed'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedFilter == tab;
          final String label = tab == 'Active'
              ? 'Active 6'
              : (tab == 'Offers' ? 'Offers 1' : 'Closed 2');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = tab;
                  });
                }
              },
              selectedColor: AppColors.dashboardTeal.withValues(alpha: 0.15),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.dashboardTeal : cardBorder,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── APPLICATION ROW CARD ───────────────────────────────────────────────────
  Widget _buildApplicationRow(
    bool isMobile,
    Map<String, dynamic> app,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final String role = app['role'];
    final String company = app['company'];
    final String stage = app['stage'];
    final String detail = app['detail'];
    final int currentStep = app['step'];

    final bool isInterview = stage == 'INTERVIEW';
    final bool isOffer = stage == 'OFFER';

    // Resolve stage colors
    Color pillBg = const Color(0xFFF1F5F9);
    Color pillText = const Color(0xFF64748B);
    if (stage == 'INTERVIEW') {
      pillBg = AppColors.dashboardTeal.withValues(alpha: 0.1);
      pillText = AppColors.dashboardTeal;
    } else if (stage == 'OFFER') {
      pillBg = AppColors.dashboardBlue.withValues(alpha: 0.1);
      pillText = AppColors.dashboardBlue;
    } else if (stage == 'IN REVIEW') {
      pillBg = AppColors.dashboardAmber.withValues(alpha: 0.1);
      pillText = AppColors.dashboardAmber;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (isOffer) {
            setState(() {
              _isOfferExpanded = !_isOfferExpanded;
            });
          } else {
            _showMockNavigation('/application-detail/$role');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isMobile ? 16 : 20),
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
              // Top line: Role, Company + Status pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role,
                          style: GoogleFonts.spaceGrotesk(
                            color: textPrimary,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '$company · ',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            // Special link click
                            if (isInterview)
                              GestureDetector(
                                onTap: () => _showInterviewOptions(context),
                                child: Text(
                                  detail,
                                  style: GoogleFonts.inter(
                                    color: AppColors.dashboardTeal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              )
                            else
                              Text(
                                detail,
                                style: GoogleFonts.inter(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stage,
                      style: GoogleFonts.jetBrainsMono(
                        color: pillText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Journey line
              _buildJourneyLine(
                isMobile,
                currentStep,
                textPrimary,
                textSecondary,
              ),

              // Offer expanded options
              if (isOffer && _isOfferExpanded) ...[
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 16),
                Text(
                  'Congratulations! TechVerse has extended an offer of \$115,000/yr base salary + equity.',
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_offerStatus == 'PENDING')
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dashboardTeal,
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _offerStatus = 'ACCEPTED';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.dashboardTeal,
                              content: Text(
                                'You accepted the offer! Congratulations!',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Accept Offer',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B6B),
                          side: const BorderSide(color: Color(0xFFFF6B6B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _offerStatus = 'DECLINED';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFFF6B6B),
                              content: Text('You declined the offer.'),
                            ),
                          );
                        },
                        child: Text(
                          'Decline',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _offerStatus == 'ACCEPTED'
                          ? AppColors.dashboardTeal.withValues(alpha: 0.1)
                          : const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _offerStatus == 'ACCEPTED'
                          ? '✓ You accepted this offer'
                          : '✗ You declined this offer',
                      style: GoogleFonts.inter(
                        color: _offerStatus == 'ACCEPTED'
                            ? AppColors.dashboardTeal
                            : const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── JOURNEY LINE ──────────────────────────────────────────────────────────
  Widget _buildJourneyLine(
    bool isMobile,
    int currentStep,
    Color textPrimary,
    Color textSecondary,
  ) {
    final stages = ['APPLIED', 'SCREENED', 'INTERVIEW', 'DECISION'];

    return Column(
      children: [
        // Dots and horizontal bar
        Stack(
          alignment: Alignment.center,
          children: [
            // Bar background
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Bar active fill
            Positioned(
              left: 16,
              right: 16,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double factor = 0;
                  if (currentStep > 1) {
                    factor = (currentStep - 1) / 3;
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 4,
                      width: constraints.maxWidth * factor,
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dots row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                final stepIndex = index + 1;
                final bool isPassed = stepIndex < currentStep;
                final bool isCurrent = stepIndex == currentStep;

                Color dotColor = const Color(0xFFCBD5E1);
                double dotSize = 10;
                BoxDecoration decoration;

                if (isPassed) {
                  dotColor = AppColors.dashboardTeal;
                  decoration = BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  );
                } else if (isCurrent) {
                  dotColor = AppColors.dashboardTeal;
                  dotSize = 14;
                  decoration = BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.dashboardTeal.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  );
                } else {
                  decoration = BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  );
                }

                return Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: decoration,
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Text labels below dots
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            final stepIndex = index + 1;
            final isCurrent = stepIndex == currentStep;

            return Text(
              stages[index],
              style: GoogleFonts.jetBrainsMono(
                color: isCurrent ? AppColors.dashboardTeal : textSecondary,
                fontSize: isMobile ? 8 : 10,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }),
        ),
      ],
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
        'icon': Icons.description_rounded,
        'label': 'Resumes',
        'route': '/candidate/resumes',
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
                                color: AppColors.dashboardTeal.withValues(
                                  alpha: 0.4,
                                ),
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
                                if (index == 0) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CandidateHomeScreen(),
                                    ),
                                  );
                                } else if (index == 1) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CandidateApplicationsScreen(),
                                    ),
                                  );
                                } else if (index == 2) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CandidateJobFeedScreen(),
                                    ),
                                  );
                                } else if (index == 3) {
                                  _showInterviewOptions(context);
                                } else if (index == 4) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CandidateResumeManagementScreen(),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const CandidateProfileSettingsScreen()),
                                  );
                                }
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
                                  color: isSelected
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardTeal,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
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

          PopupMenuButton<String>(
            tooltip: 'Switch Workspace Role',
            onSelected: (value) {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'candidate_home') {
                Navigator.of(context).pushReplacementNamed('/candidate/home');
              } else if (value == 'candidate_apps') {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/candidate/applications');
              } else if (value == 'candidate_profile') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateProfileSettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recruiter',
                child: Text(
                  'Recruiter Workspace',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_home',
                child: Text(
                  'Candidate Home',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_apps',
                child: Text(
                  'Candidate Applications',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'candidate_profile',
                child: Text(
                  'Profile & Settings',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6F7F5),
                border: Border.all(
                  color: const Color(0xFF32BAB1).withValues(alpha: 0.3),
                  width: 1,
                ),
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
      {'icon': Icons.description_rounded, 'route': '/candidate/resumes'},
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
              if (!isSelected) {
                if (index == 0) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateHomeScreen(),
                    ),
                  );
                } else if (index == 1) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateApplicationsScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateJobFeedScreen(),
                    ),
                  );
                } else if (index == 3) {
                  _showInterviewOptions(context);
                } else if (index == 4) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CandidateResumeManagementScreen(),
                    ),
                  );
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CandidateProfileSettingsScreen()),
                  );
                }
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
                    color: isSelected
                        ? AppColors.dashboardTeal
                        : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.dashboardTeal.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    item['icon'],
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardTeal,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0F172A),
                          width: 1.5,
                        ),
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
                SvgPicture.asset('assets/images/logo.svg', height: 32),
                const SizedBox(width: 10),
                Text(
                  'Applications',
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
          Text(
            'MY APPLICATIONS',
            style: GoogleFonts.spaceGrotesk(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
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

              // Notification button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
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

  // ── MOCK NAVIGATION TOASTS ─────────────────────────────────────────────────
  void _showMockNavigation(String destination) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Navigating to: $destination',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showInterviewOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Interviews Section',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dashboardTeal,
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'Interview History (CD-09)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateInterviewLobbyScreen(),
                  ),
                );
              },
              child: Text(
                'Interview Lobby (CD-05)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateFeedbackReportScreen(),
                  ),
                );
              },
              child: Text(
                'Feedback Report (CD-07)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM GRID PAINTER ─────────────────────────────────────────────────────
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
