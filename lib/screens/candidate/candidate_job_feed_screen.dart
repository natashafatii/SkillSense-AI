import 'dart:ui';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_tooltip.dart';
import '../../constants/app_colors.dart';
import '../../models/job.dart';
import '../../models/paginated_response.dart';
import '../../services/job_service.dart';
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
  bool _hasAnyJobs = true;

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
        if (page == 1 && _searchController.text.isEmpty && _selectedFilter == 'All jobs' && _locationController.text.isEmpty) {
          _hasAnyJobs = _jobs.isNotEmpty;
        }
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
                              child: _loading && _jobs.isEmpty
                                  ? const Center(child: CircularProgressIndicator(color: AppColors.dashboardTeal))
                                  : _error != null && _jobs.isEmpty
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Could not load jobs: ${_error!}'),
                                            TextButton(
                                              onPressed: () => _loadJobs(page: _page),
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        )
                                      : !_hasAnyJobs
                                          ? _buildEmptyState(isMobile)
                                          : SingleChildScrollView(
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

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 54 : 64,
              height: isMobile ? 54 : 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // --field
                borderRadius: BorderRadius.circular(isMobile ? 17 : 20),
                border: Border.all(color: const Color(0xFFE2E8F0)), // --edge2
              ),
              child: Center(
                child: Icon(
                  Icons.adjust_rounded, // target-in-circle icon
                  size: isMobile ? 20 : 24,
                  color: const Color(0xFF64748B), // --tx2
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMobile ? 'No jobs yet' : 'No jobs to show right now',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A), // --tx
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: isMobile ? -0.03 : -0.025,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? 280 : 380),
              child: Text(
                isMobile
                    ? 'New roles will appear here.'
                    : 'New roles appear here as recruiters post them. Complete your profile so the best matches rank first.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B), // --tx3
                  fontSize: isMobile ? 11 : 12.5,
                  height: 1.65,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: isMobile ? 38 : 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF17CBAC), Color(0xFF0A8A76)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17CBAC).withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 22 : 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/candidate/profile');
                },
                child: Text(
                  'Complete my profile',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600, // approximations for 550
                  ),
                ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(height: 4),
              Text(
                'We\'ll notify you when roles match',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8), // --tx4
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
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
      {'icon': Icons.adjust_rounded, 'route': '/candidate/jobs'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/applications'},
      {'icon': Icons.radio_button_checked_rounded, 'route': '/candidate/interview-lobby'},
      {'icon': Icons.person_outline_rounded, 'route': '/candidate/profile'},
    ];
    final int activeNavIndex = 1; // Jobs is index 1

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
          final isSelected = index == activeNavIndex;
          final item = dockItems[index];

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                Navigator.of(context).pushReplacementNamed(item['route']);
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
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.dashboardBlue, size: 26),
            const SizedBox(width: 8),
            Text(
              'Jobs',
              style: GoogleFonts.inter(
                color: textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.03,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'JOB FEED',
            style: GoogleFonts.spaceGrotesk(
              color: textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.05,
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
    String tooltip = '';
    if (icon == Icons.notifications_none_rounded || icon == Icons.notifications_outlined || icon == Icons.notifications) {
      tooltip = 'Notifications';
    } else if (icon == Icons.settings_outlined || icon == Icons.settings) {
      tooltip = 'Theme & settings';
    } else if (icon == Icons.search || icon == Icons.search_rounded) {
      tooltip = 'Search or jump to (⌘K)';
    } else if (icon == Icons.help_outline) {
      tooltip = 'Help & support';
    }

    return AppTooltip(
      message: tooltip,
      position: TooltipPosition.bottom,
      child: MouseRegion(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Gradient selectedGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2EE6C8), Color(0xFF0E9E8C)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17CBAC), Color(0xFF0A8A76)],
          );

    final List<BoxShadow> selectedShadow = isDark
        ? [
            BoxShadow(
              color: const Color(0xFF2EE6C8).withValues(alpha: 0.6),
              blurRadius: 22,
              spreadRadius: -6,
              offset: const Offset(0, 0),
            )
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0FB89B).withValues(alpha: 0.8),
              blurRadius: 24,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            )
          ];

    final Color inactiveBg = _hovered
        ? const Color(0xFF2EE6C8).withValues(alpha: 0.12)
        : Colors.white;

    final Color inactiveText = const Color(0xFF64748B);

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
            color: isSelected ? null : inactiveBg,
            gradient: isSelected ? selectedGradient : null,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.0)
                : Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
            boxShadow: isSelected ? selectedShadow : [],
          ),
          child: Text(
            widget.chip,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : inactiveText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
