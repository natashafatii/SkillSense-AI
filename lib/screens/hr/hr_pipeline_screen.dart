import 'dart:async';
import 'package:flutter/material.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;
import '../../widgets/recruiter_top_bar.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/application.dart';
import '../../models/job.dart';
import '../../models/resume_detail.dart';
import '../../services/application_service.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import 'schedule_interview_screen.dart';
import 'applicant_detail_preview.dart';

/// Recruiter Kanban board scoped to one job and backed by its applications.
class HrPipelineScreen extends StatefulWidget {
  final String? jobId;
  final Future<List<Job>> Function()? loadJobs;
  final Future<List<Application>> Function(String jobId)? loadApplications;
  final Future<Application> Function(String id)? loadApplication;
  final Future<ResumeDetail> Function(String id)? loadResume;
  final Future<Application> Function(Application app)? shortlistApplication;
  final Future<Application> Function(Application app)? rejectApplication;
  final Future<Application> Function(String id, String status)?
  advanceApplication;

  const HrPipelineScreen({
    super.key,
    this.jobId,
    this.loadJobs,
    this.loadApplications,
    this.loadApplication,
    this.loadResume,
    this.shortlistApplication,
    this.rejectApplication,
    this.advanceApplication,
  });

  @override
  State<HrPipelineScreen> createState() => _HrPipelineScreenState();
}

class _HrPipelineScreenState extends State<HrPipelineScreen> {
  static const _stages = [
    'APPLIED',
    'UNDER_REVIEW',
    'SHORTLISTED',
    'INTERVIEWED',
    'DECIDED',
  ];
  static const _stageColors = [
    Color(0xFF64748B),
    Color(0xFF4F83FF),
    Color(0xFF22CDB1),
    Color(0xFF7C6CF2),
    Color(0xFF10B981),
  ];

  List<Job> _jobs = [];
  List<Application> _applications = [];
  final Map<String, List<Application>> _cache = {};
  final Map<String, Future<List<Application>>> _inFlight = {};
  final Set<String> _expanded = {};
  final Set<String> _shortlisting = {};
  final Map<String, FocusNode> _viewFocusNodes = {};
  final GlobalKey _jobSwitcherKey = GlobalKey();
  String? _jobId;
  String? _error;
  bool _loading = true;
  bool _switcherLoading = false;
  int _selection = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    _loadJobs();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          !_loading &&
          _jobId != null &&
          _applications.any((a) => a.status == ApplicationStatus.applied)) {
        _selectJob(_jobId!, refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final node in _viewFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HrPipelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId == widget.jobId) return;
    final id = widget.jobId;
    if (id != null && _jobs.any((job) => job.id == id)) {
      _selectJob(id);
    } else {
      _jobId = id;
      _loadJobs();
    }
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = List<Job>.from(
        await (widget.loadJobs?.call() ?? JobService.listAllJobs()),
      );
      if (!mounted) return;
      final requestedId = _jobId;
      if (requestedId != null && !jobs.any((job) => job.id == requestedId)) {
        jobs.add(await JobService.getJob(requestedId));
        if (!mounted || _jobId != requestedId) return;
      }
      setState(() => _jobs = jobs);
      final id = _jobId ?? (jobs.isEmpty ? null : jobs.first.id);
      if (id == null) {
        setState(() => _loading = false);
      } else {
        await _selectJob(id);
      }
    } catch (error) {
      if (!mounted) return;
      final status = error is ApiException ? error.statusCode : null;
      if (status == 401) {
        try {
          await AuthService.signOut();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }
      if (status == 404) {
        setState(() {
          _jobs = [];
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = 'Could not load pipeline: $error';
        _loading = false;
      });
    }
  }

  Future<void> _selectJob(String id, {bool refresh = false}) async {
    final selection = ++_selection;
    if (refresh) _cache.remove(id);
    final cached = _cache[id];
    setState(() {
      _jobId = id;
      _error = null;
      _expanded.clear();
      _applications = cached ?? [];
      _loading = cached == null;
    });
    if (cached != null) return;
    try {
      final future = _inFlight.putIfAbsent(
        id,
        () =>
            widget.loadApplications?.call(id) ??
            ApplicationService.listAllForJob(id),
      );
      final applications = ApplicationService.forJob(await future, id);
      _cache[id] = applications;
      if (!mounted || selection != _selection || id != _jobId) return;
      setState(() {
        _applications = applications;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || selection != _selection || id != _jobId) return;
      setState(() {
        _error = 'Could not load applications: $error';
        _loading = false;
      });
    } finally {
      _inFlight.remove(id);
    }
  }

  String? _columnFor(Application app) {
    final status = (app.rawStatus ?? app.status.value).toUpperCase();
    if (status == 'REJECTED' || status == 'DECISION') return 'DECIDED';
    return _stages.contains(status) ? status : null;
  }

  String _candidateName(Application app) {
    final name = app.candidateName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final prefix = app.candidateEmail
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();
    if (prefix.isEmpty) return 'Candidate';
    return prefix
        .split(RegExp(r'\s+'))
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Future<void> _showApplication(Application app) async {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final company =
        _jobs.where((job) => job.id == app.job).firstOrNull?.recruiterCompany ??
        '';
    Widget preview() => ApplicantDetailPreview(
      initialApplication: app,
      candidateName: _candidateName(app),
      company: company,
      mobile: compact,
      loadApplication: widget.loadApplication,
      loadResume: widget.loadResume,
      onShortlist: _shortlist,
      onReject: _reject,
    );
    if (compact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .88,
          child: preview(),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
            child: preview(),
          ),
        ),
      );
    }
    if (mounted) _viewFocusNodes[app.id]?.requestFocus();
  }

  Future<bool> _shortlist(Application app) async {
    if (!_shortlisting.add(app.id)) return false;
    setState(() {});
    try {
      final updated =
          await (widget.shortlistApplication?.call(app) ??
              ApplicationService.shortlistApplication(app));
      if (!mounted) return false;
      final cached = _cache[app.job];
      if (cached != null) {
        _cache[app.job] = [
          for (final existing in cached)
            existing.id == app.id ? updated : existing,
        ];
      }
      if (_jobId == app.job) {
        setState(() {
          _applications = [
            for (final existing in _applications)
              existing.id == app.id ? updated : existing,
          ];
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Candidate shortlisted.')));
      return true;
    } catch (error) {
      if (!mounted) return false;
      final status = error is ApiException ? error.statusCode : null;
      if (status == 401) {
        try {
          await AuthService.signOut();
        } catch (_) {
          // Redirect even if the session was already ended.
        }
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return false;
      }
      final message = switch (status) {
        400 => 'Cannot shortlist from current stage.',
        403 => "You're not authorized.",
        _ => 'Could not shortlist. Please retry.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      _shortlisting.remove(app.id);
      if (mounted) setState(() {});
    }
  }

  Future<bool> _reject(Application app) async {
    if (!_shortlisting.add(app.id)) return false;
    setState(() {});
    try {
      final updated =
          await (widget.rejectApplication?.call(app) ??
              ApplicationService.rejectApplication(app));
      if (!mounted) return false;
      _cache[app.job] = [
        for (final existing in (_cache[app.job] ?? _applications))
          existing.id == app.id ? updated : existing,
      ];
      if (_jobId == app.job) {
        setState(() {
          _applications = [
            for (final existing in _applications)
              existing.id == app.id ? updated : existing,
          ];
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Candidate rejected.')));
      return true;
    } catch (error) {
      if (!mounted) return false;
      if (error is ApiException && error.statusCode == 401) {
        try {
          await AuthService.signOut();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return false;
      }
      final message = error is ApiException
          ? error.message
          : 'Could not reject. Please retry.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      _shortlisting.remove(app.id);
      if (mounted) setState(() {});
    }
  }

  void _schedule(Application app) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScheduleInterviewScreen(jobId: app.job, applicationId: app.id),
      ),
    );
  }

  Future<void> _openJobSwitcher() async {
    if (_switcherLoading || _jobId == null) return;
    setState(() => _switcherLoading = true);
    List<Job> activeJobs;
    try {
      activeJobs =
          (await (widget.loadJobs?.call() ??
                  JobService.listAllJobs(status: JobStatus.active)))
              .where((job) => job.status == JobStatus.active)
              .toList();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load active jobs.')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _switcherLoading = false);
    }
    if (!mounted) return;
    final button = _jobSwitcherKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (button is! RenderBox || overlay is! RenderBox) return;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showMenu<Job>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy + button.size.height, 0, 0),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(maxWidth: 360),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: activeJobs.isEmpty
          ? [
              const PopupMenuItem<Job>(
                enabled: false,
                child: Text('No active jobs'),
              ),
            ]
          : activeJobs.map((job) {
              final current = job.id == _jobId;
              return PopupMenuItem<Job>(
                value: job,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: current ? const Color(0xFFEAF0FF) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              job.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                color: const Color(0xFF17233B),
                                fontSize: 13,
                                fontWeight: current
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${job.location} · ${job.jobType.value}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8290AB),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (current) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF3B5AF1),
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
    );
    if (!mounted || selected == null || selected.id == _jobId) return;
    Navigator.of(context).pushReplacementNamed(
      '/recruiter/jobs/${Uri.encodeComponent(selected.id)}/pipeline',
    );
  }

  Widget _header(Job? job, bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 28, compact ? 16 : 24, 22),
    child: compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerTitle(job),
              const SizedBox(height: 12),
              _headerActions(job),
            ],
          )
        : Row(
            children: [
              Expanded(child: _headerTitle(job)),
              _headerActions(job),
            ],
          ),
  );

  Widget _headerTitle(Job? job) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        key: _jobSwitcherKey,
        onTap: _jobId == null ? null : _openJobSwitcher,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                job?.title ?? 'Applicant pipeline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF17233B),
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Color(0xFF17233B),
            ),
          ],
        ),
      ),
      Text(
        '${_applications.length} applicants',
        style: GoogleFonts.inter(color: const Color(0xFF8290AB), fontSize: 12),
      ),
    ],
  );

  Widget _headerActions(Job? job) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FilledButton.icon(
        key: const Key('pipeline-schedule-interview'),
        onPressed:
            _jobId == null ||
                !_applications.any(
                  (app) =>
                      _columnFor(app) == 'SHORTLISTED' &&
                      app.eligibleForInterview,
                )
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScheduleInterviewScreen(jobId: _jobId),
                ),
              ),
        icon: const Icon(Icons.add_circle_outline, size: 15),
        label: const Text('Schedule interview'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3B5AF1),
          textStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final job = _jobs.where((item) => item.id == _jobId).firstOrNull;
    final compact = MediaQuery.sizeOf(context).width < 900;
    final hasJobs = _jobs.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background gradient
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

          // Grid pattern overlay (Web Only)
          if (!compact)
            Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // Main workspace content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const RecruiterTopBar(
                  pageTitle: 'Pipeline',
                  mobileTitle: 'Pipeline',
                  breadcrumbSegments: ['Roles', 'Pipeline'],
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadJobs,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (!_loading && !hasJobs)
                  Expanded(child: _buildEmptyState(compact))
                else if (hasJobs) ...[
                  _header(job, compact),
                  Expanded(child: _buildKanbanBoard(compact)),
                ],
              ],
            ),
          ),

          // Mobile bottom dock
          if (compact)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── EMPTY STATE ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool compact) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: compact ? 84 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon tile (64px web / 54px mobile)
                Container(
                  width: compact ? 54 : 64,
                  height: compact ? 54 : 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(compact ? 17 : 20),
                    border: Border.all(color: const Color(0xFFE3EAF4)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.view_kanban_outlined,
                      size: compact ? 20 : 24,
                      color: const Color(0xFF8190A8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Heading
                Text(
                  compact ? 'No candidates yet' : 'No candidates in pipeline',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF17233B),
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: compact ? -0.02 : -0.025,
                  ),
                ),
                const SizedBox(height: 8),

                // Helper text
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 280 : 380),
                  child: Text(
                    compact
                        ? 'Create a role to track applicants across interview stages.'
                        : 'Create a role or post a job listing to start receiving applicants and tracking them across interview stages.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8190A8),
                      fontSize: compact ? 11 : 12.5,
                      height: 1.65,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Primary CTA — indigo gradient
                Container(
                  height: compact ? 38 : 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4D7BFA), Color(0xFF2E4FE0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4D7BFA).withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    key: const Key('pipeline-create-role-cta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 22 : 26,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed('/recruiter/create-role'),
                    child: Text(
                      'Create a role',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (!compact) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Active job listings automatically populate the applicant pipeline',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // ── KANBAN BOARD ───────────────────────────────────────────────────────────
  Widget _buildKanbanBoard(bool compact) => LayoutBuilder(
    builder: (context, constraints) {
      final width = ((constraints.maxWidth - 48 - 48) / 5).clamp(225.0, 300.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 24,
          0,
          compact ? 16 : 24,
          compact ? 84 : 16,
        ),
        child: SizedBox(
          height: constraints.maxHeight - (compact ? 84 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _stages.length; index++) ...[
                SizedBox(
                  width: width,
                  child: _column(_stages[index], _stageColors[index]),
                ),
                if (index < _stages.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      );
    },
  );

  // ── MOBILE FLOATING BOTTOM DOCK ────────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    const destinations = [
      (Icons.dashboard_outlined, '/recruiter/command-deck', 'Dashboard'),
      (Icons.grid_view_rounded, '/recruiter/job-listings', 'Jobs'),
      (Icons.view_kanban_outlined, '/recruiter/pipeline', 'Pipeline'),
      (
        Icons.radio_button_checked,
        '/recruiter/schedule-interview',
        'Interviews',
      ),
      (Icons.leaderboard_outlined, '/recruiter/rankings', 'Rankings'),
      (Icons.diamond_outlined, '/recruiter/analytics', 'Analytics'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final destination in destinations)
              Expanded(
                child: Tooltip(
                  message: destination.$3,
                  child: InkWell(
                    key: Key('pipeline-dock-${destination.$3.toLowerCase()}'),
                    onTap: destination.$3 == 'Pipeline'
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pushReplacementNamed(destination.$2),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: destination.$3 == 'Pipeline'
                          ? BoxDecoration(
                              color: const Color(0xFF4D7BFA),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4D7BFA,
                                  ).withValues(alpha: 0.34),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Icon(
                        destination.$1,
                        size: 20,
                        color: destination.$3 == 'Pipeline'
                            ? Colors.white
                            : const Color(0xFF74829E),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _column(String stage, Color color) {
    final apps = _applications.where((app) => _columnFor(app) == stage).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shown = _expanded.contains(stage) ? apps : apps.take(2).toList();
    final more = apps.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$stage · ${apps.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF27344C),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: apps.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No candidates yet',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: shown.length + (more > 0 ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => index < shown.length
                      ? _card(shown[index], stage)
                      : _moreButton(stage, more),
                ),
        ),
      ],
    );
  }

  Widget _moreButton(String stage, int more) => SizedBox(
    height: 62,
    child: CustomPaint(
      painter: const _PipelineDashedBorder(Color(0xFFD8DFEC)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded.add(stage)),
          child: Center(
            child: Text(
              '+ $more more',
              style: GoogleFonts.inter(
                color: const Color(0xFF7D8BA6),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _card(Application app, String stage) {
    final name = _candidateName(app);
    final initials = _initials(name);
    final scored = stage == 'INTERVIEWED';
    final date = scored ? (app.updatedAt ?? app.createdAt) : app.createdAt;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showApplication(app),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE9EDF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A1C315B),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE8EEFF),
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF3F5BC9),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF27344C),
                          ),
                        ),
                        Text(
                          '${scored ? 'Scored' : 'Applied'} ${_timeAgo(date)}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF8290AB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.resumeScore != null) _scoreRing(app.resumeScore!),
                ],
              ),
              const SizedBox(height: 8),
              _cardFooter(app, stage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRing(double score) {
    final color = score >= 85
        ? const Color(0xFF10B981)
        : score >= 70
        ? const Color(0xFF14B8A6)
        : score >= 55
        ? const Color(0xFFF0B33C)
        : const Color(0xFFEF4444);
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
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 3,
              backgroundColor: const Color(0xFFE5E9F1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            score.round().toString(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF27344C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFooter(Application app, String stage) {
    if (stage == 'APPLIED') {
      final focusNode = _viewFocusNodes.putIfAbsent(app.id, FocusNode.new);
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          focusNode: focusNode,
          onPressed: () => _showApplication(app),
          child: const Text('View'),
        ),
      );
    }
    if (stage == 'UNDER_REVIEW') {
      final busy = _shortlisting.contains(app.id);
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: busy ? null : () => _shortlist(app),
          child: Text(busy ? 'Shortlisting…' : 'Shortlist'),
        ),
      );
    }
    if (stage == 'SHORTLISTED') {
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: app.eligibleForInterview ? () => _schedule(app) : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B5AF1),
          ),
          child: const Text('Interview'),
        ),
      );
    }
    if (stage == 'INTERVIEWED') {
      final scores = <String>[
        if (app.technicalScore != null) 'T ${app.technicalScore!.round()}',
        if (app.behavioralScore != null) 'B ${app.behavioralScore!.round()}',
        if (app.communicationScore != null)
          'C ${app.communicationScore!.round()}',
      ];
      return Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [for (final score in scores) _scoreChip(score)],
            ),
          ),
          _badge('INTERVIEWED', const Color(0xFF0F9876)),
        ],
      );
    }
    final outcome = app.outcome?.toUpperCase();
    final label = app.rawStatus == 'REJECTED'
        ? 'NO'
        : outcome == 'NO' || outcome == 'HIRED'
        ? outcome!
        : 'DECIDED';
    return Align(
      alignment: Alignment.centerRight,
      child: _badge(
        label,
        label == 'NO' ? const Color(0xFFB45353) : const Color(0xFF0F9876),
      ),
    );
  }

  Widget _scoreChip(String score) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F5FB),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      score,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 8,
        color: const Color(0xFF64748B),
      ),
    ),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PipelineDashedBorder extends CustomPainter {
  final Color color;
  const _PipelineDashedBorder(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PipelineDashedBorder oldDelegate) =>
      oldDelegate.color != color;
}
