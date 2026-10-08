import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/application.dart';
import '../../models/paginated_response.dart';
import '../../services/application_service.dart';
import '../../widgets/candidate_side_nav.dart';
import '../../constants/app_colors.dart';

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
  bool _hasNext = false;
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
        _hasNext = response.hasNext;
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

  int get _activeCount =>
      _applications.where((a) => a.status != ApplicationStatus.decision).length;
  int get _offersCount => _applications
      .where((a) => a.status == ApplicationStatus.decision)
      .length; // Placeholder logic
  int get _closedCount =>
      _applications.where((a) => a.status == ApplicationStatus.decision).length;

  List<Application> get _visibleApplications {
    return _applications.where((a) {
      if (_filter == 'active') return a.status != ApplicationStatus.decision;
      if (_filter == 'offers') return a.status == ApplicationStatus.decision;
      if (_filter == 'closed') return a.status == ApplicationStatus.decision;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: wide ? null : _CandidateApplicationsDrawer(),
      appBar: wide ? null : AppBar(title: const Text('My applications')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            const CandidateSideNav(currentRoute: '/candidate/applications'),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(wide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_error != null)
                          _buildErrorState()
                        else if (_visibleApplications.isEmpty)
                          _buildEmptyState()
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
    );
  }

  Widget _buildTopBar(bool isWeb) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'APPLICATIONS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: const Color(0xFF475569),
            ),
          ),
          if (isWeb)
            Row(
              children: [
                Container(
                  width: 250,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search or jump to...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.notifications_none,
                      size: 20,
                      color: Color(0xFF64748B),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
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
        Row(
          children: [
            _buildFilterPill(
              'Active $_activeCount',
              'active',
              const Color(0xFFECFDF5),
              const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _buildFilterPill(
              'Offers $_offersCount',
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
        return ApplicationCard(application: _visibleApplications[index]);
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

  Widget _buildEmptyState() {
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

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
            child: const Text('Previous'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page $_page',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _hasNext ? () => _load(page: _page + 1) : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class ApplicationCard extends StatelessWidget {
  final Application application;

  const ApplicationCard({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(application.status);
    final statusText = _getStatusBadgeText(application.status);
    final statusBg = statusColor.withValues(alpha: 0.1);

    String subtext = '';
    String companyName = 'DataFlow';
    if (application.status == ApplicationStatus.applied) {
      subtext = 'Applied 2d ago';
      companyName = 'DataFlow';
    } else if (application.status == ApplicationStatus.screened) {
      subtext = 'Screening in progress';
      companyName = 'CodeCraft';
    } else if (application.status == ApplicationStatus.interviewed) {
      subtext = 'Interview Wed 13:00';
      companyName = 'TechVerse';
    } else {
      subtext = 'Offer received';
      companyName = 'NeuralTech';
    }
    return Container(
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return const Color(0xFFFBBF24); // Yellow
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
        return 'IN REVIEW';
      case ApplicationStatus.interviewed:
        return 'INTERVIEW';
      case ApplicationStatus.decision:
        return 'OFFER'; // Simplified for UI demonstration
    }
  }
}

class _ProgressBar extends StatelessWidget {
  final ApplicationStatus status;
  final Color themeColor;

  const _ProgressBar({required this.status, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final stages = ['APPLIED', 'SCREENED', 'INTERVIEW', 'DECISION'];
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

class _CandidateApplicationsDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const destinations = <({String label, String route, IconData icon})>[
      (label: 'Home', route: '/candidate/home', icon: Icons.home_outlined),
      (label: 'Jobs', route: '/candidate/jobs', icon: Icons.work_outline),
      (
        label: 'Applications',
        route: '/candidate/applications',
        icon: Icons.assignment_outlined,
      ),
      (
        label: 'Interviews',
        route: '/candidate/interviews',
        icon: Icons.event_outlined,
      ),
      (
        label: 'Resumes',
        route: '/candidate/resumes',
        icon: Icons.description_outlined,
      ),
      (
        label: 'Profile',
        route: '/candidate/profile',
        icon: Icons.person_outline,
      ),
    ];
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Candidate navigation')),
            for (final destination in destinations)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected: destination.route == '/candidate/applications',
                onTap: () => Navigator.of(
                  context,
                ).pushReplacementNamed(destination.route),
              ),
          ],
        ),
      ),
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
