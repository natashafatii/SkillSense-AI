import 'candidate_job_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/app_tooltip.dart';
import '../../models/application.dart';
import '../../models/paginated_response.dart';
import '../../services/application_service.dart';
import '../../widgets/candidate_side_nav.dart';

/// The candidate's server-backed application list.
class CandidateApplicationsScreen extends StatefulWidget {
  final Future<PaginatedResponse<Application>> Function(int page)?
  loadApplications;

  const CandidateApplicationsScreen({super.key, this.loadApplications});

  @override
  State<CandidateApplicationsScreen> createState() =>
      _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState
    extends State<CandidateApplicationsScreen> {
  List<Application> _applications = [];
  String _filter = 'active'; // 'active', 'offers', 'closed'
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await (widget.loadApplications?.call(page) ??
              ApplicationService.listApplications(page: page));
      if (!mounted || request != _request) return;
      setState(() {
        _applications = response.results;
        _page = page;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _applications = [];
        _error = e.toString();
      });
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  int get _activeCount => _applications
      .where(
        (a) =>
            a.status != ApplicationStatus.decision &&
            a.status != ApplicationStatus.rejected,
      )
      .length;
  int get _offersCount => _applications
      .where((a) => a.status == ApplicationStatus.decision)
      .length; // Placeholder logic
  int get _closedCount => _applications
      .where(
        (a) =>
            a.status == ApplicationStatus.decision ||
            a.status == ApplicationStatus.rejected,
      )
      .length;

  List<Application> get _visibleApplications {
    return _applications.where((a) {
      if (_filter == 'active')
        return a.status != ApplicationStatus.decision &&
            a.status != ApplicationStatus.rejected;
      if (_filter == 'offers') return a.status == ApplicationStatus.decision;
      if (_filter == 'closed')
        return a.status == ApplicationStatus.decision ||
            a.status == ApplicationStatus.rejected;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide)
                  const CandidateSideNav(
                    currentRoute: '/candidate/applications',
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(wide),
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.dashboardTeal,
                                ),
                              )
                            : _error != null
                            ? _buildErrorState()
                            : _applications.isEmpty
                            ? _buildEmptyState(!wide)
                            : SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  left: wide ? 40 : 16,
                                  right: wide ? 40 : 16,
                                  top: 32,
                                  bottom: wide ? 32 : 100,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 32),
                                    if (_visibleApplications.isEmpty)
                                      _buildNoFilteredApplications()
                                    else
                                      _buildGrid(wide),
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
          if (!wide)
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

  Widget _buildTopBar(bool isWeb) {
    if (!isWeb) {
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
          children: [
            const Icon(
              Icons.auto_awesome,
              color: AppColors.dashboardBlue,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Applications',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
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
            'APPLICATIONS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.05,
              color: const Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              Container(
                width: 250,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
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
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              AppTooltip(
                message: 'Notifications',
                position: TooltipPosition.bottom,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
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
                        const Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.dashboardTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AppTooltip(
                message: 'Theme & settings',
                position: TooltipPosition.bottom,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: Color(0xFF475569),
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

  Widget _buildHeader() {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Applications',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_activeCount active · $_closedCount closed',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterPill(
              'Active $_activeCount',
              'active',
              const Color(0xFFECFDF5),
              const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _buildFilterPill(
              'Decisions $_offersCount',
              'offers',
              Colors.white,
              const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            _buildFilterPill(
              'Closed $_closedCount',
              'closed',
              Colors.white,
              const Color(0xFF64748B),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterPill(
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(bool wide) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 2 : 1,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: wide ? 2.8 : 1.8,
        mainAxisExtent: 160,
      ),
      itemCount: _visibleApplications.length,
      itemBuilder: (context, index) {
        return ApplicationCard(
          application: _visibleApplications[index],
          onChanged: () => _load(page: _page),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Could not load applications: ${_error!}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        TextButton(
          onPressed: () => _load(page: _page),
          child: const Text('Retry'),
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
                  Icons.grid_view_rounded, // table/grid icon
                  size: isMobile ? 20 : 24,
                  color: const Color(0xFF64748B), // --tx2
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMobile ? 'Nothing applied yet' : 'No applications yet',
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
                    ? 'Track your applications here.'
                    : 'Apply to a role and track every stage here, from screening to offer.',
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
                  Navigator.of(context).pushReplacementNamed('/candidate/jobs');
                },
                child: Text(
                  'Browse jobs',
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
                'Applying takes about a minute',
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

  Widget _buildNoFilteredApplications() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'No applications found for this filter.',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomDock() {
    final List<Map<String, dynamic>> dockItems = [
      {'icon': Icons.home_rounded, 'route': '/candidate/home'},
      {'icon': Icons.adjust_rounded, 'route': '/candidate/jobs'},
      {'icon': Icons.grid_view_rounded, 'route': '/candidate/applications'},
      {
        'icon': Icons.radio_button_checked_rounded,
        'route': '/candidate/interview-lobby',
      }, // Intervew Hub
      {
        'icon': Icons.person_outline_rounded,
        'route': '/candidate/profile',
      }, // Profile
    ];
    final int activeNavIndex = 2; // Applications is index 2

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
              if (index != activeNavIndex) {
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'],
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class ApplicationCard extends StatelessWidget {
  final Application application;

  final VoidCallback? onChanged;
  const ApplicationCard({super.key, required this.application, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(application.status);
    final statusText = _getStatusBadgeText(application.status);
    final statusBg = statusColor.withValues(alpha: 0.1);

    String subtext = '';
    String companyName = 'Application';
    if (application.status == ApplicationStatus.applied) {
      subtext = application.assessment?['status'] == 'FAILED'
          ? 'Processing failed — tap to resolve'
          : 'Tap to view screening progress';
      companyName = 'Application';
    } else if (application.status == ApplicationStatus.screened) {
      subtext = 'Shortlisted for interview scheduling';
      companyName = 'Application';
    } else if (application.status == ApplicationStatus.interviewed) {
      subtext = 'Interview Wed 13:00';
      companyName = 'Application';
    } else if (application.status == ApplicationStatus.underReview) {
      subtext = 'Recruiter review required';
    } else if (application.status == ApplicationStatus.rejected) {
      subtext = 'Application not selected';
    } else {
      subtext = 'Decision recorded';
      companyName = 'Application';
    }
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CandidateJobDetailScreen(jobId: application.job),
          ),
        );
        onChanged?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (application.status == ApplicationStatus.interviewed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              application.jobTitle.isEmpty
                                  ? 'Job ${application.job}'
                                  : application.jobTitle,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$companyName · $subtext',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _ProgressBar(
                    status: application.status,
                    themeColor: statusColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return const Color(0xFFFBBF24); // Yellow
      case ApplicationStatus.rejected:
        return const Color(0xFFEF4444);
      case ApplicationStatus.underReview:
      case ApplicationStatus.screened:
        return const Color(0xFF94A3B8); // Grey
      case ApplicationStatus.interviewed:
        return const Color(0xFF10B981); // Green
      case ApplicationStatus.decision:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  String _getStatusBadgeText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return 'APPLIED';
      case ApplicationStatus.screened:
        return 'SHORTLISTED';
      case ApplicationStatus.underReview:
        return 'UNDER REVIEW';
      case ApplicationStatus.rejected:
        return 'REJECTED';
      case ApplicationStatus.interviewed:
        return 'INTERVIEW';
      case ApplicationStatus.decision:
        return 'DECISION';
    }
  }
}

class _ProgressBar extends StatelessWidget {
  final ApplicationStatus status;
  final Color themeColor;

  const _ProgressBar({required this.status, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final stages = ['APPLIED', 'SHORTLISTED', 'INTERVIEW', 'DECISION'];
    int currentIndex = _getStatusIndex(status);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double circleSize = 18.0;
        final double step = (width - circleSize) / (stages.length - 1);

        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              // Background line
              Positioned(
                top: 8,
                left: 9,
                right: 9,
                child: Container(height: 2, color: const Color(0xFFE2E8F0)),
              ),
              // Colored line
              Positioned(
                top: 8,
                left: 9,
                width: step * currentIndex,
                child: Container(height: 2, color: themeColor),
              ),
              // Nodes
              for (int i = 0; i < stages.length; i++)
                Positioned(
                  left: i == 0
                      ? 0
                      : (i == stages.length - 1 ? null : (step * i) + 9 - 40),
                  right: i == stages.length - 1 ? 0 : null,
                  top: 0,
                  width: (i != 0 && i != stages.length - 1) ? 80 : null,
                  child: _buildNode(
                    label: stages[i],
                    isActive: i <= currentIndex,
                    isCurrent: i == currentIndex,
                    isFirst: i == 0,
                    isLast: i == stages.length - 1,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _getStatusIndex(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.applied:
        return 0;
      case ApplicationStatus.underReview:
      case ApplicationStatus.rejected:
      case ApplicationStatus.screened:
        return 1;
      case ApplicationStatus.interviewed:
        return 2;
      case ApplicationStatus.decision:
        return 3;
    }
  }

  Widget _buildNode({
    required String label,
    required bool isActive,
    required bool isCurrent,
    required bool isFirst,
    required bool isLast,
  }) {
    return Column(
      crossAxisAlignment: isFirst
          ? CrossAxisAlignment.start
          : isLast
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: isLast ? const EdgeInsets.only(right: 0) : null,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? themeColor.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? themeColor : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class CandidateApplicationJobLink extends StatelessWidget {
  final String jobId;

  const CandidateApplicationJobLink({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: jobId.trim().isEmpty
        ? null
        : () => Navigator.of(
            context,
          ).pushNamed('/candidate/job-detail', arguments: jobId),
    child: const Text('View Job Details'),
  );
}
