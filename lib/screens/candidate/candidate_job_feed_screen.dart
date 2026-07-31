import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_job_detail_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_feedback_report_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_interview_history_screen.dart';
import 'candidate_profile_settings_screen.dart';

class CandidateJobFeedScreen extends StatefulWidget {
  const CandidateJobFeedScreen({super.key});

  @override
  State<CandidateJobFeedScreen> createState() => _CandidateJobFeedScreenState();
}

class _CandidateJobFeedScreenState extends State<CandidateJobFeedScreen> {
  final int _activeNavIndex = 2; // Jobs is index 2
  String _selectedFilter = 'Best match';
  final TextEditingController _searchController = TextEditingController();

  // Mock Job Data
  final List<Map<String, dynamic>> _jobs = [
    {
      'title': 'ML Engineer',
      'company': 'NeuralTech',
      'location': 'Remote',
      'salary': 'PKR 250–350k',
      'score': 92,
      'posted': '1d ago',
      'postedDays': 1,
      'isRemote': true,
      'isLahore': false,
      'skills': ['PyTorch', 'MLOps', 'Python', '+3'],
    },
    {
      'title': 'Django Developer',
      'company': 'CloudNine',
      'location': 'Lahore',
      'salary': 'PKR 180–260k',
      'score': 85,
      'posted': '2d ago',
      'postedDays': 2,
      'isRemote': false,
      'isLahore': true,
      'skills': ['Django', 'DRF', 'PostgreSQL'],
    },
    {
      'title': 'Backend Engineer',
      'company': 'DataFlow',
      'location': 'Hybrid',
      'salary': 'PKR 200–280k',
      'score': 78,
      'posted': '3d ago',
      'postedDays': 3,
      'isRemote': false,
      'isLahore': false,
      'skills': ['Python', 'Redis', 'Celery'],
    },
    {
      'title': 'DevOps Engineer',
      'company': 'StackUp',
      'location': 'Remote',
      'salary': 'PKR 220–300k',
      'score': 71,
      'posted': '5d ago',
      'postedDays': 5,
      'isRemote': true,
      'isLahore': false,
      'skills': ['AWS', 'Docker', 'CI/CD'],
    },
    {
      'title': 'Full Stack Dev',
      'company': 'CodeCraft',
      'location': 'Lahore',
      'salary': 'PKR 150–220k',
      'score': 64,
      'posted': '7d ago',
      'postedDays': 7,
      'isRemote': false,
      'isLahore': true,
      'skills': ['React', 'Node', 'SQL'],
    },
    {
      'title': 'Data Analyst',
      'company': 'InsightIQ',
      'location': 'On-site',
      'salary': 'PKR 120–180k',
      'score': 58,
      'posted': '10d ago',
      'postedDays': 10,
      'isRemote': false,
      'isLahore': false,
      'skills': ['SQL', 'PowerBI', 'Excel'],
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get matching filtered & sorted jobs
  List<Map<String, dynamic>> _getProcessedJobs() {
    List<Map<String, dynamic>> list = List.from(_jobs);

    // Apply Filter
    if (_selectedFilter == 'Remote') {
      list = list.where((j) => j['isRemote'] == true).toList();
    } else if (_selectedFilter == 'Lahore') {
      list = list.where((j) => j['isLahore'] == true).toList();
    }

    // Apply Sorting
    if (_selectedFilter == 'Best match') {
      list.sort((a, b) => b['score'].compareTo(a['score']));
    } else if (_selectedFilter == 'Newest') {
      list.sort((a, b) => a['postedDays'].compareTo(b['postedDays']));
    }

    return list;
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

    final processedJobs = _getProcessedJobs();

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
                                  processedJobs,
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
    List<Map<String, dynamic>> processedJobs,
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
                  'Job feed',
                  style: GoogleFonts.spaceGrotesk(
                    color: textPrimary,
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ranked by semantic match to your profile · updated 5 min ago',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Filter Chips (Web Only)
            if (!isMobile) _buildFilterChipsWeb(cardBorder),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Chips (Mobile Only)
        if (isMobile) ...[
          _buildFilterChipsMobile(cardBorder),
          const SizedBox(height: 16),
        ],

        // Jobs Grid/List
        if (isMobile)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: processedJobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, idx) {
              final job = processedJobs[idx];
              return _buildJobCard(
                isMobile,
                job,
                textPrimary,
                textSecondary,
                cardBg,
                cardBorder,
              );
            },
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.8,
            ),
            itemCount: processedJobs.length,
            itemBuilder: (context, idx) {
              final job = processedJobs[idx];
              return _buildJobCard(
                isMobile,
                job,
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

  // ── FILTER CHIPS (Web) ──────────────────────────────────────────────────────
  Widget _buildFilterChipsWeb(Color cardBorder) {
    final chips = ['Best match', 'Newest', 'Remote', 'Lahore'];

    return Row(
      children: chips.map((chip) {
        final isSelected = _selectedFilter == chip;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = chip;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.dashboardTeal : cardBorder,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.dashboardTeal.withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                chip,
                style: GoogleFonts.inter(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── FILTER CHIPS (Mobile) ──────────────────────────────────────────────────
  Widget _buildFilterChipsMobile(Color cardBorder) {
    final chips = ['Best match', 'Newest', 'Remote', 'Lahore'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = _selectedFilter == chip;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                chip,
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
                    _selectedFilter = chip;
                  });
                }
              },
              selectedColor: AppColors.dashboardTeal.withValues(alpha: 0.15),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.dashboardTeal : cardBorder,
                  width: 1.5,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── JOB CARD ───────────────────────────────────────────────────────────────
  Widget _buildJobCard(
    bool isMobile,
    Map<String, dynamic> job,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    final String title = job['title'];
    final String company = job['company'];
    final String location = job['location'];
    final String salary = job['salary'];
    final int score = job['score'];
    final List<String> skills = List<String>.from(job['skills']);
    final bool isTopMatch = score == 92; // ML Engineer top match

    // Score band colors
    Color ringColor = const Color(0xFFEF4444); // <55 Red
    if (score >= 85) {
      ringColor = const Color(0xFF10B981); // Emerald
    } else if (score >= 70) {
      ringColor = AppColors.dashboardTeal; // Teal
    } else if (score >= 55) {
      ringColor = const Color(0xFFF59E0B); // Gold
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openJobDetail(title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isTopMatch ? AppColors.dashboardTeal : cardBorder,
              width: isTopMatch ? 2.0 : 1.5,
            ),
            boxShadow: [
              if (isTopMatch)
                BoxShadow(
                  color: AppColors.dashboardTeal.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 4,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                        ),
                      ),
                      Text(
                        '$score',
                        style: GoogleFonts.spaceGrotesk(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Job details to the right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          company,
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$location · $salary',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Apply Button (Web Only)
                  if (!isMobile) _buildApplyButton(title),
                ],
              ),
              const SizedBox(height: 12),

              // Skill Chips row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            skill,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Apply Button (Mobile Only)
                  if (isMobile) _buildApplyButton(title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton(String title) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dashboardTeal,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: () => _openJobDetail(title),
      child: Text(
        'Apply',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  void _openJobDetail(String title) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CandidateJobDetailScreen(jobTitle: title),
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

          // Avatar bottom with Role Switcher
          PopupMenuButton<String>(
            tooltip: 'Switch Workspace Role',
            onSelected: (value) {
              if (value == 'recruiter') {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              } else if (value == 'candidate_home') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateHomeScreen(),
                  ),
                );
              } else if (value == 'candidate_apps') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateApplicationsScreen(),
                  ),
                );
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
                  'Jobs',
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
            'JOBS / RECOMMENDATIONS',
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
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CandidateInterviewLobbyScreen()),
                );
              },
              child: Text('Interview Lobby (CD-05)', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                  MaterialPageRoute(builder: (_) => const CandidateFeedbackReportScreen()),
                );
              },
              child: Text('Feedback Report (CD-07)', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
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
