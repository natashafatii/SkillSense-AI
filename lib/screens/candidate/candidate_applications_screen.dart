import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import '../application_screening_screen.dart';
import 'package:skillsense_ai/widgets/pointer_gesture_detector.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import '../../widgets/candidate_mobile_nav.dart';
import '../../widgets/candidate_button_style.dart';
import 'package:flutter/material.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../constants/app_colors.dart';
import '../../models/application.dart';
import '../../models/paginated_response.dart';
import '../../services/application_service.dart';
import '../../widgets/candidate_side_nav.dart';
import '../../widgets/green_gradient_background.dart';

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
      if (_filter == 'active') {
        return a.status != ApplicationStatus.decision &&
            a.status != ApplicationStatus.rejected;
      }
      if (_filter == 'offers') return a.status == ApplicationStatus.decision;
      if (_filter == 'closed') {
        return a.status == ApplicationStatus.decision ||
            a.status == ApplicationStatus.rejected;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    final workspace = Column(
      children: [
        RecruiterTopBar(pageTitle: 'Applications', candidate: true),
        Expanded(
          child: MobileEdgeShadowWrapper(
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
                      bottom: wide ? 32 : 164,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: double.infinity, child: _buildHeader()),
                        const SizedBox(height: 32),
                        if (_visibleApplications.isEmpty)
                          _buildNoFilteredApplications()
                        else
                          _buildGrid(wide),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: context.themeCanvas(const Color(0xFFF8FAFC)),
      body: Stack(
        children: [
          const GreenGradientBackground(),
          SafeArea(
            bottom: false,
            child: !wide
                ? workspace
                : CandidateSideNav(
                    currentRoute: '/candidate/applications',
                    workspace: workspace,
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

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applications', style: context.text.headlineLarge),
            const SizedBox(height: 4),
            Text(
              '$_activeCount active · $_closedCount closed',
              style: AppType.bodySm.style(
                context,
                color: context.themeForeground(TypographyColors.secondary),
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
    return PointerGestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.themeSurface(const Color(0xFFECFDF5))
              : context.themeSurface(Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : context.themeOutline(const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: AppType.caption.style(
            context,
            color: isSelected
                ? context.themeForeground(const Color(0xFF10B981))
                : context.themeForeground(TypographyColors.secondary),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(bool wide) {
    final applications = _visibleApplications;
    if (_filter == 'closed' || _filter == 'offers') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final application in applications)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: ApplicationCard(
                application: application,
                onChanged: () => _load(page: _page),
                fitContent: true,
              ),
            ),
        ],
      );
    }
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
      itemCount: applications.length,
      itemBuilder: (context, index) {
        return ApplicationCard(
          application: applications[index],
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
          style: CandidateButtonStyle.secondary(
            context,
            TextButton.styleFrom(),
          ),
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
                color: context.themeSurface(const Color(0xFFF1F5F9)), // --field
                borderRadius: BorderRadius.circular(isMobile ? 17 : 20),
                border: Border.all(
                  color: context.themeOutline(const Color(0xFFE2E8F0)),
                ), // --edge2
              ),
              child: Center(
                child: Icon(
                  Icons.grid_view_rounded, // table/grid icon
                  size: isMobile ? 20 : 24,
                  color: context.themeForeground(
                    const Color(0xFF64748B),
                  ), // --tx2
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMobile ? 'Nothing applied yet' : 'No applications yet',
              style: AppType.h3.style(
                context,
                color: context.themeForeground(TypographyColors.primary),
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
                style: AppType.caption.style(
                  context,
                  color: context.themeForeground(TypographyColors.secondary),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: CandidateButtonStyle.primaryGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: CandidateButtonStyle.teal.withValues(alpha: 0.25),
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
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed('/candidate/jobs');
                },
                child: Text(
                  'Browse jobs',
                  style: AppType.button.style(context, color: Colors.white),
                ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(height: 4),
              Text(
                'Applying takes about a minute',
                style: AppType.caption.style(
                  context,
                  color: context.themeForeground(TypographyColors.secondary),
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
          style: AppType.bodyLg.style(
            context,
            color: context.themeForeground(TypographyColors.secondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomDock() =>
      const CandidateMobileNav(currentRoute: '/candidate/applications');
}

enum _FinalDecision {
  hired,
  notSelected;

  static _FinalDecision? from(Application application) {
    if (application.status == ApplicationStatus.rejected) return notSelected;
    if (application.status != ApplicationStatus.decision) return null;
    if (application.rawStatus?.trim().toUpperCase() == 'HIRED') return hired;
    return switch (application.outcome?.trim().toUpperCase()) {
      'HIRE' || 'HIRED' => hired,
      'REJECT' ||
      'REJECTED' ||
      'NO' ||
      'NOT_SELECTED' ||
      'NOT SELECTED' => notSelected,
      _ => null,
    };
  }
}

class ApplicationCard extends StatelessWidget {
  final Application application;

  final VoidCallback? onChanged;
  final bool fitContent;
  const ApplicationCard({
    super.key,
    required this.application,
    this.onChanged,
    this.fitContent = false,
  });

  String get _title => application.jobTitle.isEmpty
      ? 'Job ${application.job}'
      : application.jobTitle;

  @override
  Widget build(BuildContext context) {
    final decision = _FinalDecision.from(application);
    final statusColor = _getStatusColor(application.status);
    final statusText = _getStatusBadgeText(application.status);
    final tone = switch (application.status) {
      ApplicationStatus.screened ||
      ApplicationStatus.interviewed => StatusTone.success,
      ApplicationStatus.scheduled ||
      ApplicationStatus.inProgress ||
      ApplicationStatus.underReview ||
      ApplicationStatus.interviewFailed => StatusTone.pending,
      ApplicationStatus.rejected => StatusTone.error,
      _ => StatusTone.neutral,
    };

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
    } else if (application.status == ApplicationStatus.scheduled) {
      subtext = 'Interview scheduled — open your lobby for joining time';
    } else if (application.status == ApplicationStatus.inProgress) {
      subtext = 'Interview in progress';
    } else if (application.status == ApplicationStatus.interviewFailed) {
      subtext = 'Interview requires recruiter follow-up';
    } else if (application.status == ApplicationStatus.interviewed) {
      subtext = 'Interview completed';
      companyName = 'Application';
    } else if (application.status == ApplicationStatus.underReview) {
      subtext = 'Recruiter review required';
    } else if (application.status == ApplicationStatus.rejected) {
      subtext = 'Application not selected';
    } else if (application.status == ApplicationStatus.unknown) {
      subtext = 'Refresh to check application status';
    } else {
      subtext = 'Decision recorded';
      companyName = 'Application';
    }
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ApplicationScreeningScreen(applicationId: application.id),
          ),
        );
        onChanged?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.themeSurface(Colors.white),
          borderRadius: BorderRadius.circular(decision == null ? 16 : 20),
          border: Border.all(
            color: context.themeOutline(const Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: decision != null
            ? _buildDecision(context, decision)
            : Stack(
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
                    padding: EdgeInsets.all(context.cardPadding),
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
                                    _title,
                                    style: AppType.h4.style(
                                      context,
                                      color: context.themeForeground(
                                        const Color(0xFF1E293B),
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$companyName · $subtext',
                                    style: context.secondaryBody,
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
                                color: tone.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: tone.foreground.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: AppType.badge.style(
                                  context,
                                  color: tone.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (fitContent)
                          const SizedBox(height: 16)
                        else
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

  Widget _buildDecision(BuildContext context, _FinalDecision decision) {
    final hired = decision == _FinalDecision.hired;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = hired
        ? (dark ? const Color(0xFF6EE7B7) : const Color(0xFF008866))
        : (dark ? const Color(0xFFFDA4AF) : const Color(0xFFC53246));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: AppType.h4.style(
                    context,
                    color: context.themeForeground(const Color(0xFF17243A)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hired ? 'HIRED' : 'NOT SELECTED',
                  style: AppType.caption.style(context, color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: AppType.bodySm.style(
                context,
                color: context.themeForeground(TypographyColors.secondary),
              ),
              children: [
                TextSpan(
                  text: hired
                      ? "Congratulations, you're hired!"
                      : 'Not selected this time.',
                  style: AppType.body.style(context, color: accent),
                ),
                TextSpan(
                  text: hired
                      ? ' Check your email for your offer and next steps.'
                      : ' Thank you for your time. Keep applying, the right role is out there.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ProgressBar(
            status: application.status,
            themeColor: const Color(0xFF3973EC),
            decisionColor: accent,
            hired: hired,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.scheduled:
      case ApplicationStatus.inProgress:
      case ApplicationStatus.interviewFailed:
      case ApplicationStatus.unknown:
        return const Color(0xFF64748B);
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
      case ApplicationStatus.scheduled:
        return 'SCHEDULED';
      case ApplicationStatus.inProgress:
        return 'IN PROGRESS';
      case ApplicationStatus.interviewFailed:
        return 'INTERVIEW FOLLOW-UP';
      case ApplicationStatus.unknown:
        return 'STATUS UNAVAILABLE';
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
  final Color? decisionColor;
  final bool hired;

  const _ProgressBar({
    required this.status,
    required this.themeColor,
    this.decisionColor,
    this.hired = false,
  });

  @override
  Widget build(BuildContext context) {
    final stages = ['APPLIED', 'SHORTLISTED', 'INTERVIEW', 'DECISION'];
    final currentIndex = decisionColor == null ? _getStatusIndex(status) : 3;

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
                child: Container(
                  height: 2,
                  color: context.themeSurface(const Color(0xFFE2E8F0)),
                ),
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
                    context,
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
      case ApplicationStatus.unknown:
      case ApplicationStatus.applied:
        return 0;
      case ApplicationStatus.underReview:
      case ApplicationStatus.rejected:
      case ApplicationStatus.screened:
        return 1;
      case ApplicationStatus.scheduled:
      case ApplicationStatus.inProgress:
      case ApplicationStatus.interviewFailed:
      case ApplicationStatus.interviewed:
        return 2;
      case ApplicationStatus.decision:
        return 3;
    }
  }

  Widget _buildNode(
    BuildContext context, {
    required String label,
    required bool isActive,
    required bool isCurrent,
    required bool isFirst,
    required bool isLast,
  }) {
    final finalAccent = isLast ? decisionColor : null;
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
                ? (finalAccent ?? themeColor).withValues(alpha: 0.2)
                : Colors.transparent,
          ),
          child: Center(
            child: Container(
              width: hired && isLast ? 14 : 8,
              height: hired && isLast ? 14 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (hired ? themeColor : finalAccent ?? themeColor)
                    : context.themeSurface(const Color(0xFFCBD5E1)),
              ),
              child: hired && isLast
                  ? Icon(
                      Icons.check,
                      size: 12,
                      color: finalAccent,
                      shadows: [Shadow(color: finalAccent!, blurRadius: 4)],
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppType.caption.style(
            context,
            color:
                finalAccent ??
                context.themeForeground(TypographyColors.secondary),
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
          ).pushNamed('/candidate/jobs/${Uri.encodeComponent(jobId.trim())}'),
    style: CandidateButtonStyle.secondary(context, TextButton.styleFrom()),
    child: const Text('View Job Details'),
  );
}
