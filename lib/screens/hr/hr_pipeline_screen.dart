import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart';
import 'schedule_interview_screen.dart';
import 'rankings_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class HrPipelineScreen extends StatefulWidget {
  const HrPipelineScreen({super.key});

  @override
  State<HrPipelineScreen> createState() => _HrPipelineScreenState();
}

class _HrPipelineScreenState extends State<HrPipelineScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Stateful candidates list representing the full cohort of 50 applicants
  late List<Map<String, dynamic>> _candidates;

  // Web threshold filter overlay visibility
  bool _showWebThresholdPopup = false;

  // Sort State: 1 = Score Descending, 2 = Score Ascending, 0 = Recency (original order)
  int _sortState = 1;

  // Score threshold
  double _minScoreFilter = 60.0;
  bool _isMinScoreFilterActive = false;

  // Mobile selected column index (for chip filtering)
  int _mobileSelectedColumn = 2; // Default to 'Shortlisted'

  // Expanded state for columns on web/mobile (+N more / Show less)
  final Map<int, bool> _columnExpanded = {
    0: false, // Pending
    1: false, // Screening
    2: false, // Shortlisted
    3: false, // Interviewed
    4: false, // Decided
  };

  // Hover states for interactions
  String? _hoveredCardId;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    // Clear jobs badge upon opening this screen
    AppNavState.unreadInterviews = 3; // Keep unread interviews badge visible on interviews tab

    _candidates = [
      // Shortlisted (8 candidates total)
      {
        'id': 'c1',
        'initials': 'AK',
        'name': 'Ayesha Khalid',
        'subtitle': '8 of 9 skills matched',
        'score': 91,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFF3E8FF),
        't': 8.4,
        'b': 8.6,
        'c': 7.9,
      },
      {
        'id': 'c2',
        'initials': 'BM',
        'name': 'Bilal Mahmood',
        'subtitle': '7 of 9 skills matched',
        'score': 84,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFD1FAE5),
        't': 8.1,
        'b': 7.2,
        'c': 7.6,
      },
      {
        'id': 'c3',
        'initials': 'FF',
        'name': 'F. Fatima',
        'subtitle': '6 of 9 skills matched',
        'score': 78,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFEFF6FF),
        't': 7.5,
        'b': 7.8,
        'c': 7.2,
      },
      {
        'id': 'c4',
        'initials': 'NU',
        'name': 'Natasha Usman',
        'subtitle': '6 of 9 skills matched',
        'score': 73,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFF5F3FF),
      },
      {
        'id': 'c5',
        'initials': 'ZF',
        'name': 'Zara Fatima',
        'subtitle': '5 of 9 skills matched',
        'score': 67,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFFFFBEB),
      },
      {
        'id': 'c6',
        'initials': 'AA',
        'name': 'Ali Ahmed',
        'subtitle': '5 of 9 skills matched',
        'score': 65,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFEFF6FF),
      },
      {
        'id': 'c7',
        'initials': 'SA',
        'name': 'Sana Alvi',
        'subtitle': '6 of 9 skills matched',
        'score': 70,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFECFDF5),
      },
      {
        'id': 'c8',
        'initials': 'HM',
        'name': 'Hamza Malik',
        'subtitle': '6 of 9 skills matched',
        'score': 72,
        'stage': 'shortlisted',
        'selected': false,
        'avatarBg': const Color(0xFFF3E8FF),
      },

      // Screening (10 candidates total)
      {
        'id': 's1',
        'initials': 'ZA',
        'name': 'Z. Abdullah',
        'subtitle': 'Parsing resume...',
        'score': 74,
        'stage': 'screening',
        'selected': false,
        'avatarBg': const Color(0xFFDBEAFE),
        'parsingProgress': 0.60, // DistilBERT 60%
      },
      {
        'id': 's2',
        'initials': 'KM',
        'name': 'Kamran Khan',
        'subtitle': '5 skills matched',
        'score': 61,
        'stage': 'screening',
        'selected': false,
        'avatarBg': const Color(0xFFD1FAE5),
      },
      {
        'id': 's3',
        'initials': 'OM',
        'name': 'Omar Munir',
        'subtitle': '4 skills matched',
        'score': 58,
        'stage': 'screening',
        'selected': false,
        'avatarBg': const Color(0xFFFEF3C7),
      },
      ...List.generate(7, (i) => {
        'id': 's_dummy_$i',
        'initials': 'S${i + 4}',
        'name': 'Screening Candidate ${i + 4}',
        'subtitle': 'Parsing complete',
        'score': 50 + i * 4,
        'stage': 'screening',
        'selected': false,
        'avatarBg': const Color(0xFFF1F5F9),
      }),

      // Pending (26 candidates total)
      {
        'id': 'p1',
        'initials': 'MJ',
        'name': 'M. Junaid',
        'subtitle': 'Applied 2h ago',
        'score': 62,
        'stage': 'pending',
        'selected': false,
        'avatarBg': const Color(0xFFFEF3C7),
      },
      {
        'id': 'p2',
        'initials': 'RA',
        'name': 'R. Ahmed',
        'subtitle': 'Applied 6h ago',
        'score': 55,
        'stage': 'pending',
        'selected': false,
        'avatarBg': const Color(0xFFFCE7F3),
      },
      ...List.generate(24, (i) => {
        'id': 'p_dummy_$i',
        'initials': 'P${i + 3}',
        'name': 'Pending Applicant ${i + 3}',
        'subtitle': 'Applied ${i + 1}d ago',
        'score': 45 + (i % 15),
        'stage': 'pending',
        'selected': false,
        'avatarBg': const Color(0xFFF1F5F9),
      }),

      // Interviewed (3 candidates total)
      {
        'id': 'i1',
        'initials': 'SK',
        'name': 'Saad Khan',
        'subtitle': 'Scored 14 min ago',
        'score': 81,
        'stage': 'interviewed',
        'selected': false,
        'avatarBg': const Color(0xFFEFF6FF),
        't': 8.2,
        'b': 7.9,
        'c': 8.1,
      },
      {
        'id': 'i2',
        'initials': 'OS',
        'name': 'Osman Sheikh',
        'subtitle': 'Scored 2d ago',
        'score': 75,
        'stage': 'interviewed',
        'selected': false,
        'avatarBg': const Color(0xFFECFDF5),
        't': 7.6,
        'b': 7.4,
        'c': 7.5,
      },
      {
        'id': 'i3',
        'initials': 'WA',
        'name': 'Waleed Ali',
        'subtitle': 'Scored 3d ago',
        'score': 69,
        'stage': 'interviewed',
        'selected': false,
        'avatarBg': const Color(0xFFFFFBEB),
        't': 7.0,
        'b': 6.8,
        'c': 6.9,
      },

      // Decided (3 candidates total)
      {
        'id': 'd1',
        'initials': 'HA',
        'name': 'Hassan Ali',
        'subtitle': 'Below threshold',
        'score': 38,
        'stage': 'decided',
        'selected': false,
        'avatarBg': const Color(0xFFFEE2E2),
      },
      {
        'id': 'd2',
        'initials': 'SM',
        'name': 'Saira Malik',
        'subtitle': 'Offered position',
        'score': 89,
        'stage': 'decided',
        'selected': false,
        'avatarBg': const Color(0xFFECFDF5),
      },
      {
        'id': 'd3',
        'initials': 'NK',
        'name': 'Noman Khan',
        'subtitle': 'Declined offer',
        'score': 71,
        'stage': 'decided',
        'selected': false,
        'avatarBg': const Color(0xFFF1F5F9),
      },
    ];

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── SORTING HELPER ──
  void _cycleSort() {
    setState(() {
      _sortState = (_sortState + 1) % 3;
    });
  }

  // Helper to fetch list of selected candidates
  List<Map<String, dynamic>> _getSelectedCandidates() {
    return _candidates.where((c) => c['selected'] == true).toList();
  }

  // Bulk schedule routing
  void _navigateToSchedule() {
    final selected = _getSelectedCandidates();
    Navigator.of(context).pushReplacementNamed('/schedule', arguments: selected);
  }

  // Stages name map
  String _getStageNameFromIndex(int index) {
    switch (index) {
      case 0:
        return 'pending';
      case 1:
        return 'screening';
      case 2:
        return 'shortlisted';
      case 3:
        return 'interviewed';
      case 4:
        return 'decided';
      default:
        return '';
    }
  }

  int _getStageIndexFromName(String stage) {
    switch (stage) {
      case 'pending':
        return 0;
      case 'screening':
        return 1;
      case 'shortlisted':
        return 2;
      case 'interviewed':
        return 3;
      case 'decided':
        return 4;
      default:
        return 0;
    }
  }

  // Get active candidates list filtered, sorted, searched
  List<Map<String, dynamic>> _getColumnCards(int stageIndex) {
    final stageName = _getStageNameFromIndex(stageIndex);
    final stageCandidates = _candidates.where((c) => c['stage'] == stageName).toList();

    // Search query filter
    final query = _searchController.text.toLowerCase();
    var filtered = stageCandidates.where((c) {
      final name = c['name'].toString().toLowerCase();
      final subtitle = c['subtitle'].toString().toLowerCase();
      return name.contains(query) || subtitle.contains(query);
    }).toList();

    // Apply sorting
    if (_sortState == 1) {
      filtered.sort((a, b) => b['score'].compareTo(a['score']));
    } else if (_sortState == 2) {
      filtered.sort((a, b) => a['score'].compareTo(b['score']));
    } else {
      // Recency / Original (sorted by ID)
      filtered.sort((a, b) => a['id'].compareTo(b['id']));
    }

    return filtered;
  }

  // Get dynamic count of candidate stage list
  int _getColumnCount(int index) {
    return _candidates.where((c) => c['stage'] == _getStageNameFromIndex(index)).length;
  }

  // Get top candidate ID in shortlisted column
  String? _getTopShortlistedCandidateId() {
    final shortlisted = _candidates.where((c) => c['stage'] == 'shortlisted').toList();
    if (shortlisted.isEmpty) return null;
    int maxScore = -1;
    String? topId;
    for (var c in shortlisted) {
      if (c['score'] > maxScore) {
        maxScore = c['score'];
        topId = c['id'];
      }
    }
    return topId;
  }

  // Mobile transitions via buttons
  void _transitionCandidate(Map<String, dynamic> candidate) {
    final currentStage = candidate['stage'] as String;
    final currentIndex = _getStageIndexFromName(currentStage);
    if (currentIndex < 4) {
      final nextIndex = currentIndex + 1;
      final nextStageName = _getStageNameFromIndex(nextIndex);
      setState(() {
        candidate['stage'] = nextStageName;

        // Auto details transition
        if (nextStageName == 'screening') {
          candidate['subtitle'] = '6 skills matched';
          candidate['parsingProgress'] = null;
        } else if (nextStageName == 'shortlisted') {
          candidate['subtitle'] = '7 of 9 skills matched';
        } else if (nextStageName == 'interviewed') {
          candidate['subtitle'] = 'Scored just now';
          candidate['t'] ??= 8.0;
          candidate['b'] ??= 7.0;
          candidate['c'] ??= 7.0;
        } else if (nextStageName == 'decided') {
          candidate['subtitle'] = candidate['score'] >= 60 ? 'Offered position' : 'Below threshold';
        }
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved ${candidate['name']} to ${_getColumnTitle(nextIndex)}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // Mobile floating action button
      floatingActionButton: isMobile && _getSelectedCandidates().isNotEmpty
          ? FloatingActionButton(
              onPressed: _navigateToSchedule,
              backgroundColor: AppColors.dashboardBlue,
              child: const Icon(Icons.calendar_today_outlined, color: Colors.white),
            )
          : null,
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

          // ── MAIN CONTENT ROW ───────────────────────────────────────────────
          Row(
            children: [
              // 1. LEFT RAIL (Web Only)
              if (!isMobile) _buildLeftRail(context),

              // 2. WORKSPACE
              Expanded(
                child: Column(
                  children: [
                    // Top Bar
                    _buildTopBar(isMobile),

                    // Header Area (Clickable sorting/filtering)
                    _buildHeaderArea(isMobile),

                    // Board / Kanban view (Supports DND on web)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 768) {
                            return _buildWebKanbanBoard();
                          } else {
                            return _buildMobileKanbanStack();
                          }
                        },
                      ),
                    ),

                    // Bottom navigation dock (Mobile Only)
                    if (isMobile) _buildBottomDock(context),
                  ],
                ),
              ),
            ],
          ),

          // Web threshold popup
          if (_showWebThresholdPopup && !isMobile)
            Positioned(
              top: 110,
              right: 210,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Score Filter',
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch.adaptive(
                            value: _isMinScoreFilterActive,
                            activeColor: AppColors.dashboardBlue,
                            onChanged: (val) {
                              setState(() {
                                _isMinScoreFilterActive = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${_minScoreFilter.toInt()}',
                            style: GoogleFonts.jetBrainsMono(
                              color: _isMinScoreFilterActive ? AppColors.dashboardBlue : const Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _minScoreFilter,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              activeColor: AppColors.dashboardBlue,
                              onChanged: _isMinScoreFilterActive
                                  ? (val) {
                                      setState(() {
                                        _minScoreFilter = val;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showWebThresholdPopup = false;
                            });
                          },
                          child: const Text('Close'),
                        ),
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

  // ── LEFT RAIL NAVIGATION ───────────────────────────────────────────────────
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
                final isSelected = index == 1; // Jobs
                final item = navItems[index];
                final bool hasBadge = index == 2 && AppNavState.unreadInterviews > 0;

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
                              if (!isSelected) {
                                Widget target;
                                if (index == 0) {
                                  target = const CommandDeckScreen();
                                } else if (index == 1) {
                                  target = const HrPipelineScreen();
                                } else if (index == 2) {
                                  target = const ScheduleInterviewScreen();
                                } else if (index == 3) {
                                  target = const RankingsScreen();
                                } else if (index == 4) {
                                  target = const AnalyticsScreen();
                                } else {
                                  target = const SettingsScreen();
                                }
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => target),
                                );
                              }
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
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
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

          // User Avatar at Bottom
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

  // ── TOP BAR (Collapsed on Mobile) ──────────────────────────────────────────
  Widget _buildTopBar(bool isMobile) {
    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: _isSearchFocused
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search applicants...',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _isSearchFocused = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/dashboard');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Senior Django Developer',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Color(0xFF0F172A), size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearchFocused = true;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
          // Breadcrumbs
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/dashboard');
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
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    'SENIOR DJANGO DEV',
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
                'APPLICANTS',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Search & Actions
          Row(
            children: [
              // Search field
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
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 16),
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

              // Notification Icon
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardRed,
              ),

              const SizedBox(width: 10),

              // Globe Icon
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

  // ── HEADER AREA (Sort / Filters / Bulk Action) ─────────────────────────────
  Widget _buildHeaderArea(bool isMobile) {
    final selectedCount = _getSelectedCandidates().length;
    final isBulkEnabled = selectedCount >= 1;

    if (isMobile) {
      // Clean header on mobile: filter icon button on the right
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '48 Applicants',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: _isMinScoreFilterActive || _sortState != 1 ? AppColors.dashboardBlue : const Color(0xFF475569),
              ),
              onPressed: _showMobileFilterBottomSheet,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Senior Django Developer',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '48 applicants · re-ranked 2 min ago',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Sorting and Filtering chips + Bulk Action
          Row(
            children: [
              // Score sort chip
              GestureDetector(
                onTap: _cycleSort,
                child: _buildHeaderButton(
                  child: Row(
                    children: [
                      Text(
                        _sortState == 1
                            ? 'Score ↓'
                            : _sortState == 2
                                ? 'Score ↑'
                                : 'Score (Recency)',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _sortState == 1
                            ? Icons.arrow_downward_rounded
                            : _sortState == 2
                                ? Icons.arrow_upward_rounded
                                : Icons.restore_rounded,
                        size: 13,
                        color: const Color(0xFF475569),
                      ),
                    ],
                  ),
                  backgroundColor: _sortState != 0 ? const Color(0xFFEEF2FF) : Colors.white,
                  borderColor: _sortState != 0 ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                ),
              ),

              const SizedBox(width: 8),

              // Threshold chip
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showWebThresholdPopup = !_showWebThresholdPopup;
                  });
                },
                child: _buildHeaderButton(
                  child: Text(
                    _isMinScoreFilterActive
                        ? 'Min ${_minScoreFilter.toInt()}'
                        : 'Min 60',
                    style: GoogleFonts.inter(
                      color: _isMinScoreFilterActive ? AppColors.dashboardBlue : const Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: _isMinScoreFilterActive ? const Color(0xFFEEF2FF) : Colors.white,
                  borderColor: _isMinScoreFilterActive ? AppColors.dashboardBlue : const Color(0xFFE2E8F0),
                ),
              ),

              const SizedBox(width: 12),

              // Schedule Interview Solid Button
              MouseRegion(
                cursor: isBulkEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
                child: GestureDetector(
                  onTap: isBulkEnabled ? _navigateToSchedule : null,
                  child: Opacity(
                    opacity: isBulkEnabled ? 1.0 : 0.5,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.dashboardBlue,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isBulkEnabled
                            ? [
                                BoxShadow(
                                  color: AppColors.dashboardBlue.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              'Schedule interview ($selectedCount)',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required Widget child,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Center(child: child),
    );
  }

  // ── WEB KANBAN VIEW (Adjacent DND Columns) ─────────────────────────────────
  Widget _buildWebKanbanBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(5, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 4 ? 0 : 14),
              child: _buildKanbanColumn(index: index, isMobile: false),
            ),
          );
        }),
      ),
    );
  }

  // ── MOBILE TAB/CHIP VIEW (Filters Active Single Stack) ─────────────────────
  Widget _buildMobileKanbanStack() {
    final List<String> columnTitles = ['PENDING', 'SCREENING', 'SHORTLISTED', 'INTERVIEWED', 'DECIDED'];

    return Column(
      children: [
        // Horizontal Filter Chips Scrollable Row
        Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: columnTitles.length,
            itemBuilder: (context, index) {
              final isSelected = _mobileSelectedColumn == index;
              final stateColor = _getColumnStateColor(index);
              final count = _getColumnCount(index);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stateColor,
                          boxShadow: [
                            BoxShadow(
                              color: stateColor.withOpacity(0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${columnTitles[index]} $count',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.dashboardBlue,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _mobileSelectedColumn = index;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),

        // Single list viewport of active stage on mobile
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildKanbanColumn(index: _mobileSelectedColumn, isMobile: true),
          ),
        ),
      ],
    );
  }

  // ── BUILD KANBAN COLUMN (With DND DragTarget on Web) ───────────────────────
  Widget _buildKanbanColumn({required int index, bool isMobile = false}) {
    final stateColor = _getColumnStateColor(index);
    final columnName = _getColumnTitle(index);
    final count = _getColumnCount(index);

    // Get sorted, searched, active cards
    final allCards = _getColumnCards(index);
    final isExpanded = _columnExpanded[index] == true;
    final displayLimit = isExpanded ? allCards.length : 3;

    final displayedCards = allCards.take(displayLimit).toList();
    final remainingCount = allCards.length - displayedCards.length;

    Widget columnBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stateColor,
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withOpacity(0.8),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                columnName,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Scrollable List area
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              ...List.generate(displayedCards.length, (cardIndex) {
                final cardData = displayedCards[cardIndex];
                final cardWidget = _buildKanbanCard(cardData, isMobile);

                // Web: wrap card in Draggable widget
                if (!isMobile) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Draggable<Map<String, dynamic>>(
                      data: cardData,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 250,
                          child: _buildKanbanCard(cardData, false),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: cardWidget,
                      ),
                      child: cardWidget,
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: cardWidget,
                );
              }),

              // Load more pill
              if (remainingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildExpandCollapseButton(
                    label: isMobile ? 'Load more' : '+ $remainingCount more',
                    onTap: () {
                      setState(() {
                        _columnExpanded[index] = true;
                      });
                    },
                  ),
                )
              else if (isExpanded && allCards.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildExpandCollapseButton(
                    label: 'Show less',
                    onTap: () {
                      setState(() {
                        _columnExpanded[index] = false;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    // If web, wrap in DragTarget
    if (!isMobile) {
      return DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) {
          final dragged = details.data;
          final sourceStageIndex = _getStageIndexFromName(dragged['stage']);
          // Only adjacent columns are eligible
          return (index - sourceStageIndex).abs() == 1;
        },
        onAcceptWithDetails: (details) {
          final dragged = details.data;
          final nextStageName = _getStageNameFromIndex(index);
          setState(() {
            dragged['stage'] = nextStageName;

            // Re-evaluate descriptors
            if (nextStageName == 'screening') {
              dragged['subtitle'] = '6 skills matched';
              dragged['parsingProgress'] = null;
            } else if (nextStageName == 'shortlisted') {
              dragged['subtitle'] = '7 of 9 skills matched';
            } else if (nextStageName == 'interviewed') {
              dragged['subtitle'] = 'Scored just now';
              dragged['t'] ??= 8.0;
              dragged['b'] ??= 7.0;
              dragged['c'] ??= 7.0;
            } else if (nextStageName == 'decided') {
              dragged['subtitle'] = dragged['score'] >= 60 ? 'Offered position' : 'Below threshold';
            }
          });
        },
        builder: (context, candidateData, rejectedData) {
          final isOver = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isOver ? AppColors.dashboardBlue.withOpacity(0.04) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: columnBody,
          );
        },
      );
    }

    return columnBody;
  }

  // ── DYNAMIC CARD COMPONENT ─────────────────────────────────────────────────
  Widget _buildKanbanCard(Map<String, dynamic> data, bool isMobile) {
    final String id = data['id'];
    final String initials = data['initials'] ?? '';
    final String name = data['name'] ?? '';
    final String subtitle = data['subtitle'] ?? '';
    final int score = data['score'] ?? 0;
    final Color scoreColor = _getScoreColor(score);

    // Compute verdict badges based on score
    String? badgeText;
    Color? badgeColor;

    final String stage = data['stage'];
    if (stage == 'shortlisted' || stage == 'interviewed' || stage == 'decided') {
      if (score >= 80) {
        badgeText = 'STRONG YES';
        badgeColor = AppColors.dashboardTeal;
      } else if (score >= 60) {
        badgeText = 'YES';
        badgeColor = AppColors.dashboardBlue;
      } else if (score >= 50) {
        badgeText = 'MAYBE';
        badgeColor = AppColors.dashboardAmber;
      } else {
        badgeText = 'NO';
        badgeColor = AppColors.dashboardRed;
      }
    }

    // Single-glow rule: Top candidate in shortlisted column
    final String? topShortlistedId = _getTopShortlistedCandidateId();
    final bool isTopShortlisted = stage == 'shortlisted' && id == topShortlistedId;
    final bool isHotCard = isTopShortlisted && (!isMobile || _mobileSelectedColumn == 2);

    // Check if card is faded under "Min 60" score filter
    final bool isBelowThreshold = _isMinScoreFilterActive && score < _minScoreFilter;

    // Hover Animation Setup
    final isHovered = _hoveredCardId == id && !isBelowThreshold;

    Widget cardContent = MouseRegion(
      onEnter: (_) => setState(() => _hoveredCardId = id),
      onExit: (_) => setState(() => _hoveredCardId = null),
      cursor: isBelowThreshold ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isBelowThreshold
            ? null
            : () {
                Navigator.pushNamed(context, '/report');
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHotCard
                  ? const Color(0xFF34E3B0) // Radiant teal border for hot card
                  : const Color(0xFFE2E8F0),
              width: isHotCard ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(isHovered ? 0.08 : 0.02),
                blurRadius: isHovered ? 16 : 10,
                offset: Offset(0, isHovered ? 6 : 2),
              ),
              if (isHotCard)
                BoxShadow(
                  color: const Color(0xFF34E3B0).withOpacity(0.18),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Select checkbox
                  GestureDetector(
                    onTap: isBelowThreshold
                        ? null
                        : () {
                            setState(() {
                              data['selected'] = !(data['selected'] ?? false);
                            });
                          },
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: (data['selected'] ?? false) ? AppColors.dashboardBlue : Colors.transparent,
                        border: Border.all(
                          color: (data['selected'] ?? false) ? Colors.transparent : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: (data['selected'] ?? false)
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ),

                  // Avatar
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data['avatarBg'] ?? const Color(0xFFF1F5F9),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Name & Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Score Ring
                  _buildScoreRing(score: score, ringColor: scoreColor),
                ],
              ),

              // Action Buttons & Badges (Render only if applicable)
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badges or Score Breakdowns
                  if (stage == 'screening' && data['parsingProgress'] != null)
                    _buildStatusBadge(
                      label: 'DISTILBERT ${(data['parsingProgress'] * 100).toInt()}%',
                      color: AppColors.dashboardBlue,
                    )
                  else if (badgeText != null)
                    _buildStatusBadge(label: badgeText, color: badgeColor!)
                  else if (stage == 'interviewed' && data['t'] != null)
                    Text(
                      'T ${data['t']} · B ${data['b']}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Action Buttons (Pending: View / Screening: Shortlist / Shortlisted: Interview)
                  if (stage == 'pending')
                    _buildSmallActionButton(
                      label: 'View',
                      isFilled: false,
                      onTap: () {
                        if (isMobile) {
                          _transitionCandidate(data);
                        } else {
                          Navigator.pushNamed(context, '/report');
                        }
                      },
                    )
                  else if (stage == 'screening' && data['parsingProgress'] == null)
                    _buildSmallActionButton(
                      label: 'Shortlist',
                      isFilled: true,
                      onTap: () {
                        if (isMobile) {
                          _transitionCandidate(data);
                        } else {
                          setState(() {
                            data['stage'] = 'shortlisted';
                            data['subtitle'] = '7 of 9 skills matched';
                          });
                        }
                      },
                    )
                  else if (stage == 'shortlisted')
                    _buildSmallActionButton(
                      label: 'Interview',
                      isFilled: true,
                      onTap: () {
                        if (isMobile) {
                          _transitionCandidate(data);
                        } else {
                          setState(() {
                            data['stage'] = 'interviewed';
                            data['subtitle'] = 'Scored just now';
                            data['t'] = 8.0;
                            data['b'] = 7.0;
                            data['c'] = 7.0;
                          });
                          Navigator.pushNamed(context, '/monitor');
                        }
                      },
                    )
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Apply fading if score falls below threshold
    return Opacity(
      opacity: isBelowThreshold ? 0.2 : 1.0,
      child: IgnorePointer(
        ignoring: isBelowThreshold,
        child: cardContent,
      ),
    );
  }

  Widget _buildScoreRing({required int score, required Color ringColor}) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 3.5,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(ringColor),
          ),
          Text(
            '$score',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({required String label, required Color color}) {
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

  Widget _buildSmallActionButton({
    required String label,
    required bool isFilled,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 28,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? AppColors.dashboardBlue : Colors.white,
          foregroundColor: isFilled ? Colors.white : const Color(0xFF475569),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isFilled ? BorderSide.none : const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── INLINE COLUMN EXPANDERS ────────────────────────────────────────────────
  Widget _buildExpandCollapseButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── MOBILE FILTER BOTTOM SHEET ─────────────────────────────────────────────
  void _showMobileFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters & Sorting',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Sorting
                    Text(
                      'SORT BY',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildModalSortOption(
                          label: 'Score ↓',
                          isSelected: _sortState == 1,
                          onTap: () {
                            setModalState(() => _sortState = 1);
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildModalSortOption(
                          label: 'Score ↑',
                          isSelected: _sortState == 2,
                          onTap: () {
                            setModalState(() => _sortState = 2);
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildModalSortOption(
                          label: 'Recency',
                          isSelected: _sortState == 0,
                          onTap: () {
                            setModalState(() => _sortState = 0);
                            setState(() {});
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Score threshold slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MIN SCORE THRESHOLD',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Switch.adaptive(
                          value: _isMinScoreFilterActive,
                          activeColor: AppColors.dashboardBlue,
                          onChanged: (val) {
                            setModalState(() => _isMinScoreFilterActive = val);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${_minScoreFilter.toInt()}',
                          style: GoogleFonts.jetBrainsMono(
                            color: _isMinScoreFilterActive ? AppColors.dashboardBlue : const Color(0xFF94A3B8),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _minScoreFilter,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            activeColor: AppColors.dashboardBlue,
                            inactiveColor: const Color(0xFFE2E8F0),
                            onChanged: _isMinScoreFilterActive
                                ? (val) {
                                    setModalState(() => _minScoreFilter = val);
                                    setState(() {});
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dashboardBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Filters',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        );
      },
    );
  }

  Widget _buildModalSortOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.dashboardBlue : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? AppColors.dashboardBlue : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── BOTTOM DOCK NAVIGATION (Mobile Only) ───────────────────────────────────
  Widget _buildBottomDock(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Interviews', 'route': '/schedule'},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'route': '/rankings'},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'route': '/analytics'},
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
          final isSelected = index == 1; // "Jobs" active
          final item = navItems[index];

          return GestureDetector(
            onTap: () {
              if (index != 1) {
                Navigator.of(context).pushReplacementNamed(item['route']);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSelected ? AppColors.dashboardBlue : Colors.transparent,
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

  // ── DATA ACCESS HELPERS ────────────────────────────────────────────────────
  Color _getColumnStateColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF94A3B8); // Gray
      case 1:
        return AppColors.dashboardBlue; // Blue
      case 2:
        return AppColors.dashboardTeal; // Teal
      case 3:
        return const Color(0xFF8B5CF6); // Purple
      case 4:
        return const Color(0xFF22C55E); // Green
      default:
        return Colors.grey;
    }
  }

  String _getColumnTitle(int index) {
    switch (index) {
      case 0:
        return 'PENDING';
      case 1:
        return 'SCREENING';
      case 2:
        return 'SHORTLISTED';
      case 3:
        return 'INTERVIEWED';
      case 4:
        return 'DECIDED';
      default:
        return '';
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.dashboardTeal;
    if (score >= 60) return AppColors.dashboardBlue;
    if (score >= 50) return AppColors.dashboardAmber;
    return AppColors.dashboardRed;
  }
}
