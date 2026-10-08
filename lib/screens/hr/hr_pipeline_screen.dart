import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/application.dart';
import '../../models/job.dart';
import '../../services/application_service.dart';
import '../../services/job_service.dart';
import 'candidate_report_screen.dart';
import 'schedule_interview_screen.dart';

/// Recruiter Kanban board scoped to one job and backed by its applications.
class HrPipelineScreen extends StatefulWidget {
  final String? jobId;
  final Future<List<Job>> Function()? loadJobs;
  final Future<List<Application>> Function(String jobId)? loadApplications;
  final Future<Application> Function(String id)? loadApplication;
  final Future<Application> Function(String id, String status)?
  advanceApplication;

  const HrPipelineScreen({
    super.key,
    this.jobId,
    this.loadJobs,
    this.loadApplications,
    this.loadApplication,
    this.advanceApplication,
  });

  @override
  State<HrPipelineScreen> createState() => _HrPipelineScreenState();
}

class _HrPipelineScreenState extends State<HrPipelineScreen> {
  static const _stages = [
    'APPLIED',
    'SCREENING',
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
  String? _jobId;
  String? _error;
  bool _loading = true;
  int _selection = 0;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    _loadJobs();
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

  String _columnFor(Application app) =>
      switch ((app.rawStatus ?? app.status.value).toUpperCase()) {
        'PENDING' || 'APPLIED' => 'APPLIED',
        'SCREENED' || 'SCREENING' => 'SCREENING',
        'SHORTLISTED' => 'SHORTLISTED',
        'INTERVIEWED' => 'INTERVIEWED',
        'DECISION' || 'DECIDED' => 'DECIDED',
        _ => 'APPLIED',
      };

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
    try {
      final detail =
          await (widget.loadApplication?.call(app.id) ??
              ApplicationService.getApplication(app.id));
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_candidateName(detail)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.candidateEmail),
              const SizedBox(height: 8),
              Text('Status: ${detail.rawStatus ?? detail.status.value}'),
              Text('Applied ${_timeAgo(detail.createdAt)}'),
            ],
          ),
          actions: [
            if (detail.resumeId?.isNotEmpty == true)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CandidateReportScreen(
                        applicationId: detail.id,
                        resumeId: detail.resumeId,
                      ),
                    ),
                  );
                },
                child: const Text('Resume report'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load application: $error')),
        );
      }
    }
  }

  Future<void> _shortlist(Application app) async {
    try {
      final updated =
          await (widget.advanceApplication?.call(app.id, 'SHORTLISTED') ??
              ApplicationService.advanceToStatus(
                applicationId: app.id,
                status: 'SHORTLISTED',
              ));
      if (_columnFor(updated) != 'SHORTLISTED') {
        throw StateError('The server did not confirm the shortlist.');
      }
      if (!mounted || _jobId != app.job) return;
      final next = [
        for (final current in _applications)
          current.id == app.id ? updated : current,
      ];
      setState(() {
        _applications = next;
        _cache[app.job] = next;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not shortlist candidate: $error')),
        );
      }
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

  Widget _topBar(Job? job) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'ROLES / ${job?.title.toUpperCase() ?? 'SELECT A ROLE'} / PIPELINE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Icon(
          Icons.notifications_none_rounded,
          size: 18,
          color: Color(0xFF64748B),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.language_rounded, size: 18, color: Color(0xFF64748B)),
      ],
    ),
  );

  Widget _header(Job? job, bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 18, compact ? 16 : 24, 14),
    child: compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerTitle(job),
              const SizedBox(height: 12),
              _headerActions(),
            ],
          )
        : Row(
            children: [
              Expanded(child: _headerTitle(job)),
              _headerActions(),
            ],
          ),
  );

  Widget _headerTitle(Job? job) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        job?.title ?? 'Applicant pipeline',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF17233B),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        '${_applications.length} applicants',
        style: GoogleFonts.inter(color: const Color(0xFF8290AB), fontSize: 11),
      ),
    ],
  );

  Widget _headerActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_jobs.length > 1)
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _jobId,
            items: [
              for (final job in _jobs)
                DropdownMenuItem(
                  value: job.id,
                  child: Text(job.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id != null) _selectJob(id);
            },
          ),
        ),
      if (_jobs.length > 1) const SizedBox(width: 12),
      FilledButton.icon(
        onPressed: _jobId == null
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
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(job),
            _header(job, compact),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadJobs,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (!_loading && _jobs.isEmpty)
              const Expanded(
                child: Center(child: Text('No recruiter jobs found.')),
              )
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = ((constraints.maxWidth - 48 - 48) / 5).clamp(
                      225.0,
                      300.0,
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(
                        compact ? 16 : 24,
                        0,
                        compact ? 16 : 24,
                        16,
                      ),
                      child: SizedBox(
                        height: constraints.maxHeight - 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var index = 0;
                              index < _stages.length;
                              index++
                            ) ...[
                              SizedBox(
                                width: width,
                                child: _column(
                                  _stages[index],
                                  _stageColors[index],
                                ),
                              ),
                              if (index < _stages.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
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
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
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
              Text(
                '$stage · ${apps.length}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF27344C),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: apps.isEmpty
              ? Center(
                  child: Text(
                    'No candidates yet',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _card(shown[index], stage),
                ),
        ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => setState(() => _expanded.add(stage)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD8DFEC)),
                foregroundColor: const Color(0xFF7D8BA6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '＋ $more more',
                style: GoogleFonts.inter(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(Application app, String stage) {
    final name = _candidateName(app);
    final initials = _initials(name);
    final scored = stage == 'INTERVIEWED';
    final date = scored ? (app.updatedAt ?? app.createdAt) : app.createdAt;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showApplication(app),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EDF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
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
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () => _showApplication(app),
          child: const Text('View'),
        ),
      );
    }
    if (stage == 'SCREENING') {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () => _shortlist(app),
          child: const Text('Shortlist'),
        ),
      );
    }
    if (stage == 'SHORTLISTED') {
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => _schedule(app),
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
    final label = outcome == 'NO' || outcome == 'HIRED' ? outcome! : 'DECIDED';
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
