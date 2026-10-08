import 'dart:ui';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../models/job.dart';
import '../../models/paginated_response.dart';
import '../../services/job_service.dart';
import 'candidate_home_screen.dart';
import 'candidate_applications_screen.dart';
import 'candidate_interview_lobby_screen.dart';
import 'candidate_feedback_report_screen.dart';
import 'candidate_resume_management_screen.dart';
import 'candidate_interview_history_screen.dart';
import 'candidate_profile_settings_screen.dart';
import '../../widgets/candidate_side_nav.dart';
import 'candidate_notifications_screen.dart';
import 'widgets/candidate_job_card.dart';

class CandidateJobFeedScreen extends StatefulWidget {
  final Future<PaginatedResponse<Job>> Function(int page)? loadJobs;

  const CandidateJobFeedScreen({super.key, this.loadJobs});

  @override
  State<CandidateJobFeedScreen> createState() => _CandidateJobFeedScreenState();
}

class _CandidateJobFeedScreenState extends State<CandidateJobFeedScreen> {
  final int _activeNavIndex = 2; // Jobs is index 2
  String _selectedFilter = 'All jobs';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  Timer? _searchDebounce;
  CancelToken? _jobsCancelToken;
  JobType? _jobType;
  ExperienceLevel? _experienceLevel;

  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs({int page = 1}) async {
    final generation = ++_requestGeneration;
    _jobsCancelToken?.cancel('A newer job search started.');
    final cancelToken = CancelToken();
    _jobsCancelToken = cancelToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await (widget.loadJobs?.call(page) ??
              JobService.listJobs(
                status: JobStatus.active,
                titleContains: _searchController.text,
                jobType: _selectedFilter == 'Remote'
                    ? JobType.remote
                    : _jobType,
                experienceLevel: _experienceLevel,
                locationContains: _selectedFilter == 'Lahore'
                    ? 'Lahore'
                    : _locationController.text,
                page: page,
                cancelToken: cancelToken,
              ));
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _jobs = response.results
            .where((job) => job.isActive && job.id.isNotEmpty)
            .toList();
        _page = page;
      });
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _jobs = [];
          _error = e.toString();
        });
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _jobsCancelToken?.cancel();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _queueSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadJobs(),
    );
  }

  void _selectFilter(String chip) {
    _searchDebounce?.cancel();
    setState(() {
      _selectedFilter = chip;
      if (chip == 'Remote') _jobType = JobType.remote;
      if (chip == 'Lahore') _locationController.text = 'Lahore';
      if (chip == 'All jobs') {
        _jobType = null;
        _experienceLevel = null;
        _locationController.clear();
      }
    });
    _loadJobs();
  }

  List<Job> _getProcessedJobs() {
    final jobs = List<Job>.from(_jobs);
    if (_selectedFilter == 'Newest') {
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return jobs;
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
                      if (!isMobile)
                        const CandidateSideNav(currentRoute: '/candidate/jobs'),

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
                                  left: 22,
                                  right: 22,
                                  top: 16,
                                  bottom: isMobile ? 100 : 32,
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
    List<Job> processedJobs,
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Job feed',
                        style: GoogleFonts.spaceGrotesk(
                          color: textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.025,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 10,
                              color: AppColors.dashboardTeal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SBERT',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Ranked by semantic match to your profile · updated 5 min ago',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips (Web Only)
            if (!isMobile) ...[
              const SizedBox(width: 12),
              Expanded(child: _buildFilterChipsWeb(cardBorder)),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Filter Chips (Mobile Only)
        if (isMobile) ...[
          _buildFilterChipsMobile(cardBorder),
          const SizedBox(height: 16),
        ],

        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Column(
            children: [
              Text('Could not load jobs: ${_error!}'),
              TextButton(
                onPressed: () => _loadJobs(page: _page),
                child: const Text('Retry'),
              ),
            ],
          ),
        if (!_loading && _error == null && processedJobs.isEmpty)
          const Text('No active jobs found.'),
        if (!_loading && _error == null)
          if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: processedJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, idx) {
                final job = processedJobs[idx];
                return CandidateJobCard(
                  job: job,
                  isMobile: isMobile,
                  isHot: idx == 0,
                  onApply: () => _openJobDetail(job.title, job.id),
                );
              },
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 104,
              ),
              itemCount: processedJobs.length,
              itemBuilder: (context, idx) {
                final job = processedJobs[idx];
                return CandidateJobCard(
                  job: job,
                  isMobile: isMobile,
                  isHot: idx == 0,
                  onApply: () => _openJobDetail(job.title, job.id),
                );
              },
            ),
      ],
    );
  }

  // ── FILTER CHIPS (Web) ──────────────────────────────────────────────────────
  Widget _buildFilterChipsWeb(Color cardBorder) {
    final chips = ['Best match', 'Newest', 'Remote', 'Lahore'];

    return SingleChildScrollView(
      key: const Key('job-feed-filter-scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: chips.map((chip) {
          final isSelected =
              _selectedFilter == chip ||
              (_selectedFilter == 'All jobs' && chip == 'Best match');
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _HoverableFilterChip(
              chip: chip,
              isSelected: isSelected,
              onTap: () => _selectFilter(chip),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── FILTER CHIPS (Mobile) ──────────────────────────────────────────────────
  Widget _buildFilterChipsMobile(Color cardBorder) {
    final chips = ['Best match', 'Newest', 'Remote', 'Lahore'];

    return SingleChildScrollView(
      key: const Key('job-feed-filter-scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected =
              _selectedFilter == chip ||
              (_selectedFilter == 'All jobs' && chip == 'Best match');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _HoverableFilterChip(
              chip: chip,
              isSelected: isSelected,
              onTap: () => _selectFilter(chip),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openJobDetail(String title, String jobId) {
    Navigator.of(context).pushReplacementNamed('/candidate/jobs/$jobId');
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
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
                    MaterialPageRoute(
                      builder: (_) => const CandidateProfileSettingsScreen(),
                    ),
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
                  onChanged: (_) => _queueSearch(),
                  onSubmitted: (_) {
                    _searchDebounce?.cancel();
                    _loadJobs();
                  },
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

              // Notification bell button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardTeal,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateNotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Settings icon
              _buildTopBarIconButton(
                icon: Icons.settings_outlined,
                hasBadge: false,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CandidateProfileSettingsScreen(),
                  ),
                ),
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
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
        ),
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

class _HoverableFilterChip extends StatefulWidget {
  final String chip;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoverableFilterChip({
    required this.chip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HoverableFilterChip> createState() => _HoverableFilterChipState();
}

class _HoverableFilterChipState extends State<_HoverableFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    // Teal-tinted background (rgba(46,230,200,.12)) + teal border + teal text.
    final selectedBg = const Color(0xFF2EE6C8).withValues(alpha: 0.12);
    final selectedText = AppColors.dashboardTeal;

    // Inactive: white/near-white background, --tx3 text.
    // Hover: light background tint.
    final inactiveBg = _hovered
        ? Colors.black.withValues(alpha: 0.03)
        : Colors.white;
    final inactiveText = const Color(0xFF64748B);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : inactiveBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.dashboardTeal
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Text(
            widget.chip,
            style: GoogleFonts.inter(
              color: isSelected ? selectedText : inactiveText,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
