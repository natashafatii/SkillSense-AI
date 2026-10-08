import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../constants/app_colors.dart';

class JobListingsScreen extends StatefulWidget {
  final Future<List<Job>> Function()? loadJobs;

  const JobListingsScreen({super.key, this.loadJobs});

  @override
  State<JobListingsScreen> createState() => _JobListingsScreenState();
}

class _JobListingsScreenState extends State<JobListingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  JobStatus _activeFilter = JobStatus.active;
  bool _isLoading = true;
  List<Job> _allJobs = [];
  String? _loadError;
  String? _hoveredJobId;

  int get _activeCount =>
      _allJobs.where((j) => j.status == JobStatus.active).length;
  int get _draftCount =>
      _allJobs.where((j) => j.status == JobStatus.draft).length;
  int get _closedCount =>
      _allJobs.where((j) => j.status == JobStatus.closed).length;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
    _fetchJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final jobs = await (widget.loadJobs?.call() ?? JobService.listAllJobs());
      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Unable to load job listings.';
          _isLoading = false;
        });
      }
    }
  }

  Color _getRingColor(double? score) {
    if (score == null || score <= 0) return const Color(0xFFCBD5E1);
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF14B8A6);
    if (score >= 55) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _metadata(Job job) {
    final parts = <String>[];
    if (job.department.trim().isNotEmpty) parts.add(job.department.trim());
    final mode = job.jobType.value.toLowerCase();
    final modeLabel = '${mode[0].toUpperCase()}${mode.substring(1)}';
    parts.add('${job.location} ($modeLabel)');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = job.deadline;
    final daysUntilClose = deadline == null
        ? null
        : DateTime(
            deadline.year,
            deadline.month,
            deadline.day,
          ).difference(today).inDays;
    if (daysUntilClose != null && daysUntilClose >= 0 && daysUntilClose <= 7) {
      parts.add(
        daysUntilClose == 0 ? 'Closes today' : 'Closes in ${daysUntilClose}d',
      );
    } else {
      parts.add('Posted ${_timeAgo(job.createdAt)}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (!isMobile) _buildWebTopBar(),
                if (isMobile) _buildMobileTopBar(),
                _buildHeaderRow(isMobile),
                _buildFilterChips(isMobile),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _loadError != null
                      ? Center(child: Text(_loadError!))
                      : _buildListPanel(isMobile),
                ),
              ],
            ),
          ),
          if (isMobile) _buildBottomDock(),
        ],
      ),
    );
  }

  Widget _buildWebTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'WORKSPACE',
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
                'JOB LISTINGS',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSearchFocused
                        ? AppColors.dashboardBlue
                        : const Color(0xFFE2E8F0),
                    width: _isSearchFocused ? 1.8 : 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
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
  }) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
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
              decoration: const BoxDecoration(
                color: AppColors.dashboardRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildMobileTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          SvgPicture.asset('assets/images/logo.svg', width: 26, height: 26),
          const SizedBox(width: 8),
          Text(
            'Jobs',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job listings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.48,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_activeCount active · $_draftCount drafts · $_closedCount closed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildNewRoleButton(),
        ],
      ),
    );
  }

  Widget _buildNewRoleButton() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: TextButton(
      onPressed: () =>
          Navigator.of(context).pushNamed('/recruiter/create-role'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        '＋ New role',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _buildFilterChips(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('Active $_activeCount', JobStatus.active),
            const SizedBox(width: 8),
            _buildChip('Draft $_draftCount', JobStatus.draft),
            const SizedBox(width: 8),
            _buildChip('Closed $_closedCount', JobStatus.closed),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, JobStatus status) {
    final isActive = _activeFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildListPanel(bool isMobile) {
    final filteredJobs = _allJobs
        .where((j) => j.status == _activeFilter)
        .toList();
    filteredJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        0,
        isMobile ? 16 : 24,
        isMobile ? 100 : 16,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_activeFilter.value.toLowerCase().replaceFirst(RegExp(r"^[a-z]"), _activeFilter.value[0])} roles',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Sort: Newest',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: filteredJobs.isEmpty
                ? Center(
                    child: Text(
                      'No ${_activeFilter.value.toLowerCase()} roles yet',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filteredJobs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      return _buildJobRow(filteredJobs[index], isMobile);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobRow(Job job, bool isMobile) {
    final hovered = _hoveredJobId == job.id;
    final badgeColor = job.isActive
        ? const Color(0xFF047857)
        : const Color(0xFF64748B);
    final badgeBackground = job.isActive
        ? const Color(0xFFDDF7E9)
        : const Color(0xFFF1F5F9);
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredJobId = job.id),
      onExit: (_) => setState(() => _hoveredJobId = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: hovered ? const Color(0xFFF8FAFF) : Colors.white,
        foregroundDecoration: hovered
            ? BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: InkWell(
          onTap: () => Navigator.of(
            context,
          ).pushNamed('/recruiter/rankings', arguments: job.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildScoreRing(job.averageScore),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _metadata(job),
                        maxLines: isMobile ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildApplicantCount(job.applicantCount, isMobile: true),
                      const SizedBox(height: 5),
                      _buildStatusBadge(job, badgeColor, badgeBackground),
                    ],
                  )
                else ...[
                  _buildApplicantCount(job.applicantCount, isMobile: false),
                  const SizedBox(width: 12),
                  _buildStatusBadge(job, badgeColor, badgeBackground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRing(double? score) {
    final hasScore = score != null && score > 0;
    final color = _getRingColor(score);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: hasScore ? (score / 100).clamp(0.0, 1.0) : 0,
              strokeWidth: 3.5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            hasScore ? score.round().toString() : '—',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hasScore
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCount(int count, {required bool isMobile}) => Text(
    '$count applicants',
    style: GoogleFonts.jetBrainsMono(
      fontSize: isMobile ? 10 : 12,
      color: const Color(0xFF64748B),
    ),
  );

  Widget _buildStatusBadge(Job job, Color color, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      job.status.value,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  Widget _buildBottomDock() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dockIcon(Icons.dashboard_outlined, '/recruiter/command-deck'),
            _dockIcon(
              Icons.menu_book_rounded,
              '/recruiter/job-listings',
              isActive: true,
            ),
            _dockIcon(Icons.view_column_outlined, '/recruiter/pipeline'),
            _dockIcon(
              Icons.calendar_month_outlined,
              '/recruiter/schedule-interview',
            ),
            _dockIcon(Icons.analytics_outlined, '/recruiter/analytics'),
          ],
        ),
      ),
    );
  }

  Widget _dockIcon(IconData icon, String route, {bool isActive = false}) {
    return GestureDetector(
      onTap: () {
        if (!isActive) Navigator.of(context).pushReplacementNamed(route);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF64748B),
          size: 24,
        ),
      ),
    );
  }
}

class RecruiterNotificationsScreen extends StatelessWidget {
  const RecruiterNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(title: const Text('Notifications')),
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 36,
            color: Color(0xFF64748B),
          ),
          SizedBox(height: 12),
          Text('You’re all caught up.'),
        ],
      ),
    ),
  );
}
