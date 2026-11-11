import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/api_contract.dart';
import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../models/resume_detail.dart';
import '../../models/screening_assessment.dart';
import '../../services/api_exception.dart';
import '../../services/application_service.dart';
import '../../services/foreground_poller.dart';
import '../../services/job_service.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../services/resume_download.dart';
import '../../services/resume_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/question_preparation_panel.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'recruitment_review_screen.dart';
import 'schedule_interview_screen.dart';

part 'candidate_report_content.dart';
part 'candidate_report_evidence.dart';
part 'candidate_report_plan.dart';

/// Recruiter report for an application selected from a role or opened directly.
class CandidateReportScreen extends StatefulWidget {
  const CandidateReportScreen({
    super.key,
    this.resumeId,
    this.applicationId,
    this.loadApplication,
    this.loadResume,
    this.workflow,
  });

  final String? resumeId;
  final String? applicationId;
  final Future<Application> Function(String id)? loadApplication;
  final Future<ResumeDetail> Function(String id)? loadResume;
  final RecruitmentWorkflowService? workflow;

  @override
  State<CandidateReportScreen> createState() => _CandidateReportScreenState();
}

typedef _ReportData = ({
  Application application,
  ScreeningAssessment? assessment,
  ResumeDetail? resume,
  bool resumeUnavailable,
});

class _CandidateReportScreenState extends State<CandidateReportScreen> {
  final _session = SessionScope.generation;
  late final _workflow = widget.workflow ?? RecruitmentWorkflowService();
  late final ForegroundPoller<_ReportData> _poller;
  CancelToken? _request;
  CancelToken? _interviewRequest;
  Future<RecruiterInterview?>? _interview;
  Future<List<Job>>? _jobs;
  Future<List<Application>>? _candidates;
  String? _jobId;
  String? _selectedId;
  _ReportData? _data;
  String? _error;
  String? _notice;
  bool _loading = false;

  bool get _signedIn => _session == SessionScope.generation;
  String? get _applicationId => _selectedId ?? widget.applicationId?.trim();

  @override
  void initState() {
    super.initState();
    _poller = ForegroundPoller(
      read: (token) => _read(token, poll: true),
      isVisible: () => mounted && ModalRoute.of(context)?.isCurrent != false,
      isPending: _isPending,
      onData: _accept,
      onStopped: (error) {
        if (mounted && _signedIn && _data != null) {
          if (error is ApiException && error.accessUnavailable) {
            setState(() {
              _clearReport();
              _error = 'This candidate report is unavailable.';
            });
          } else if (_isPending(_data!)) {
            setState(
              () => _notice =
                  'Processing is still pending. Refresh to check again.',
            );
          }
        }
      },
    );
    SessionScope.invalidations.addListener(_clearSession);
    if (widget.applicationId == null) _jobs = _loadJobs();
    if (_applicationId?.isNotEmpty == true) _load();
  }

  @override
  void didUpdateWidget(covariant CandidateReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_signedIn ||
        (widget.applicationId == oldWidget.applicationId &&
            widget.resumeId == oldWidget.resumeId)) {
      return;
    }
    _clearReport();
    _selectedId = null;
    _jobId = null;
    _candidates = null;
    _jobs = widget.applicationId == null ? _loadJobs() : null;
    if (_applicationId?.isNotEmpty == true) _load();
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(_clearSession);
    _clearReport();
    _poller.dispose();
    super.dispose();
  }

  void _clearReport() {
    _request?.cancel();
    _interviewRequest?.cancel();
    _poller.stop();
    _request = null;
    _interviewRequest = null;
    _interview = null;
    _data = null;
    _error = null;
    _notice = null;
    _loading = false;
  }

  void _clearSession() {
    setState(() {
      _clearReport();
      _selectedId = null;
      _jobId = null;
      _jobs = null;
      _candidates = null;
    });
  }

  bool _isPending(_ReportData data) =>
      data.assessment?.pending == true || data.resume?.isPending == true;

  Future<_ReportData> _read(CancelToken token, {bool poll = false}) async {
    final id = _applicationId!;
    final expectedResume = _selectedId == null ? widget.resumeId?.trim() : null;
    final application =
        await (widget.loadApplication?.call(id) ??
            ApplicationService.getApplication(id, cancelToken: token));
    if (!_signedIn || token.isCancelled) {
      throw StateError('Report request ended.');
    }
    if (application.id != id ||
        (expectedResume?.isNotEmpty == true &&
            application.resumeId != expectedResume) ||
        (_jobId != null && application.job != _jobId)) {
      throw const FormatException(
        'The response does not match the selected application.',
      );
    }

    final resumeId = application.resumeId;
    final previousResume = _data?.resume;

    Future<(ResumeDetail?, bool)> readResume() async {
      if (resumeId == null || resumeId.isEmpty) return (null, false);
      if (poll &&
          previousResume?.id == resumeId &&
          previousResume?.isParsed == true) {
        return (previousResume, false);
      }
      try {
        final resume =
            await (widget.loadResume?.call(resumeId) ??
                ResumeService.getResumeDetail(
                  resumeId,
                  refresh: true,
                  cancelToken: token,
                ));
        if (resume.id != resumeId) {
          throw const FormatException('Resume identity mismatch.');
        }
        return (resume, false);
      } catch (_) {
        return (null, true);
      }
    }

    final (resume, resumeUnavailable) = await readResume();
    return (
      application: application,
      assessment: application.screening,
      resume: resume,
      resumeUnavailable: resumeUnavailable,
    );
  }

  void _accept(_ReportData data, {bool refreshInterview = false}) {
    if (!mounted || !_signedIn) return;
    setState(() {
      final old = _data?.application;
      _data = data;
      _error = null;
      _notice = null;
      if (_jobId == null && data.application.job.isNotEmpty) {
        _jobId = data.application.job;
        _candidates = _loadCandidates(_jobId!);
      }
      if (refreshInterview ||
          _interview == null ||
          old?.status != data.application.status) {
        _readInterview(data.application.id);
      }
    });
  }

  void _readInterview(String id) {
    _interviewRequest?.cancel();
    final token = _interviewRequest = CancelToken();
    _interview = _workflow
        .interviews(applicationId: id, cancelToken: token)
        .then(
          (rows) => rows.where((row) => row.applicationId == id).firstOrNull,
        );
    // The report can be offscreen before its FutureBuilder attaches.
    _interview!.ignore();
  }

  Future<void> _load({bool refreshCandidates = false}) async {
    if (!_signedIn || _applicationId?.isNotEmpty != true) return;
    _poller.stop();
    _request?.cancel();
    final token = _request = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
      if (refreshCandidates && _jobId != null) {
        _candidates = _loadCandidates(_jobId!);
      }
    });
    try {
      final data = await _read(token);
      if (!mounted || !_signedIn || token != _request) return;
      _accept(data, refreshInterview: refreshCandidates);
      if (_isPending(data)) _poller.start();
    } catch (_) {
      if (mounted && _signedIn && token == _request) {
        setState(() {
          _data = null;
          _error = 'Could not load this candidate report.';
        });
      }
    } finally {
      if (mounted && token == _request) setState(() => _loading = false);
    }
  }

  Future<List<Application>> _loadCandidates(String jobId) {
    final result = ApplicationService.listAllForJob(jobId);
    result.ignore();
    return result;
  }

  Future<List<Job>> _loadJobs() {
    final result = JobService.listAllJobs();
    result.ignore();
    return result;
  }

  void _selectJob(String? id) {
    if (!_signedIn || id == null || id == _jobId) return;
    setState(() {
      _clearReport();
      _jobId = id;
      _selectedId = null;
      _candidates = _loadCandidates(id);
    });
  }

  void _selectCandidate(String? id) {
    if (!_signedIn || id == null || id == _applicationId) return;
    setState(() {
      _clearReport();
      _selectedId = id;
    });
    _load();
  }

  Future<void> _openReview(Application app, {String? interviewId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecruitmentReviewScreen(
          applicationId: app.id,
          interviewId: interviewId,
        ),
      ),
    );
    if (mounted && _applicationId == app.id) _load(refreshCandidates: true);
  }

  Future<void> _schedule(Application app) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ScheduleInterviewScreen(jobId: app.job, applicationId: app.id),
      ),
    );
    if (mounted && _applicationId == app.id) _load(refreshCandidates: true);
  }

  Widget _picker<T>({
    required String label,
    required Future<List<T>> future,
    required String? selection,
    required String Function(T) id,
    required String Function(T) title,
    required ValueChanged<String?> onSelected,
    required VoidCallback retry,
  }) => FutureBuilder<List<T>>(
    key: ValueKey(future),
    future: future,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? <T>[];
      if (snapshot.connectionState != ConnectionState.done && rows.isEmpty) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return TextButton(
          onPressed: retry,
          child: Text('Could not load ${label.toLowerCase()}s. Retry'),
        );
      }
      if (rows.isEmpty) return Text('No ${label.toLowerCase()}s available.');
      return DropdownMenu<String>(
        key: ValueKey((label, selection)),
        expandedInsets: EdgeInsets.zero,
        label: Text(label),
        initialSelection: selection,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 360,
        inputDecorationTheme: InputDecorationThemeData(
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
        ),
        dropdownMenuEntries: [
          for (final row in rows)
            DropdownMenuEntry(value: id(row), label: title(row)),
        ],
        onSelected: onSelected,
      );
    },
  );

  Widget _selectors(double width) {
    final roles = _picker<Job>(
      label: 'Role',
      future: _jobs!,
      selection: _jobId,
      id: (job) => job.id,
      title: (job) => job.title,
      onSelected: _selectJob,
      retry: () => setState(() => _jobs = _loadJobs()),
    );
    final candidates = _candidates;
    if (candidates == null) return roles;
    final applicants = _picker<Application>(
      label: 'Candidate',
      future: candidates,
      selection: _selectedId,
      id: (app) => app.id,
      title: (app) => '${_candidateName(app)} · ${_statusLabel(app.status)}',
      onSelected: _selectCandidate,
      retry: () => setState(() => _candidates = _loadCandidates(_jobId!)),
    );
    return _ReportColumns(
      width: width,
      columns: 2,
      children: [roles, applicants],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = _data?.application;
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final body = Column(
      children: [
        RecruiterTopBar(
          pageTitle: 'Candidate report',
          breadcrumbSegments: [
            'Jobs',
            if (app != null) app.jobTitle,
            'Candidate report',
          ],
          profileReference: true,
          showSearch: false,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = constraints.maxWidth < 680 ? 16.0 : 32.0;
              final width = constraints.maxWidth - gutter * 2;
              final data = _data;
              return RefreshIndicator(
                onRefresh: () => _load(refreshCandidates: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 28),
                      sliver: SliverList.list(
                        children: [
                          if (widget.applicationId != null &&
                              Navigator.of(context).canPop())
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to applicants'),
                              ),
                            ),
                          if (_jobs != null) ...[
                            _selectors(width),
                            const SizedBox(height: _gap),
                          ],
                          if (!_signedIn)
                            const _ReportMessage(
                              'Account session changed. Reopen the report.',
                            )
                          else if (data != null)
                            ..._report(data)
                          else if (_loading)
                            const _ReportMessage(
                              'Loading candidate report…',
                              loading: true,
                            )
                          else if (_error case final error?)
                            _ReportMessage(
                              error,
                              action: OutlinedButton(
                                onPressed: () => _load(refreshCandidates: true),
                                child: const Text('Retry'),
                              ),
                            )
                          else
                            _ReportMessage(
                              'Select a role and candidate to open their report.',
                              action: OutlinedButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed('/recruiter/pipeline'),
                                child: const Text('Open pipeline'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (mobile)
          const RecruiterMobileNav(currentRoute: '/recruiter/candidate-report'),
      ],
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _accent,
          onPrimary: Colors.white,
          onSurface: _ink,
          surface: _surface,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _edge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _ink,
            fontSize: 14,
            height: 1.45,
          ),
          child: body,
        ),
      ),
    );
  }

  List<Widget> _report(_ReportData data) {
    final app = data.application;
    final assessment = data.assessment;
    final resume = data.resume;
    final fit = _SkillFit(assessment, resume);
    return [
      FutureBuilder<List<Application>>(
        future: _candidates,
        builder: (context, snapshot) {
          final candidates = _rankedCandidates(snapshot.data ?? const [], app);
          final index = candidates.indexWhere(
            (candidate) => candidate.id == app.id,
          );
          final rank = app.resumeScore == null || index == -1
              ? null
              : candidates.indexWhere(
                      (candidate) => candidate.resumeScore == app.resumeScore,
                    ) +
                    1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CandidateHeading(
                application: app,
                rank: rank,
                candidateCount: candidates.length,
                onPrevious: index > 0
                    ? () => _selectCandidate(candidates[index - 1].id)
                    : null,
                onNext: index >= 0 && index + 1 < candidates.length
                    ? () => _selectCandidate(candidates[index + 1].id)
                    : null,
                onReview: () => _openReview(app),
                onRefresh: _loading
                    ? null
                    : () => _load(refreshCandidates: true),
              ),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Candidate ranking and navigation are temporarily unavailable.',
                    style: _mutedStyle,
                  ),
                ),
            ],
          );
        },
      ),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_notice case final notice?)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(notice, style: _mutedStyle),
        ),
      const SizedBox(height: _gap),
      _MatchCard(application: app, assessment: assessment, fit: fit),
      const SizedBox(height: _gap),
      FutureBuilder<RecruiterInterview?>(
        future: _interview,
        builder: (context, snapshot) {
          final current = snapshot.connectionState == ConnectionState.done;
          final interview = current ? snapshot.data : null;
          return _ReportBody(
            application: app,
            resume: resume,
            assessment: assessment,
            fit: fit,
            resumeUnavailable: data.resumeUnavailable,
            interview: interview,
            interviewLoading: !current,
            interviewUnavailable: snapshot.hasError,
            retryInterview: () => setState(() => _readInterview(app.id)),
            onManageInterview:
                interview != null &&
                    app.status == ApplicationStatus.scheduled &&
                    interview.workflowState == 'SCHEDULED'
                ? () => _openReview(app, interviewId: interview.id)
                : null,
            onSchedule: app.eligibleForInterview ? () => _schedule(app) : null,
          );
        },
      ),
      const SizedBox(height: _gap),
      FutureBuilder<RecruiterInterview?>(
        future: _interview,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ReportPanel(
              title: 'Interview plan',
              child: LinearProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return _ReportPanel(
              title: 'Interview plan',
              child: _ReportMessage(
                'Could not load the interview plan.',
                action: TextButton(
                  onPressed: () => setState(() => _readInterview(app.id)),
                  child: const Text('Retry'),
                ),
              ),
            );
          }
          final interview = snapshot.data;
          if (interview != null) {
            return _ScheduledPlan(
              interview: interview,
              focusAreas: fit.missing,
            );
          }
          return _DraftPlan(
            key: ValueKey(app.id),
            application: app,
            focusAreas: fit.missing,
          );
        },
      ),
    ];
  }
}

List<Application> _rankedCandidates(
  List<Application> candidates,
  Application current,
) {
  if (candidates.isEmpty) return const [];
  final unique = {for (final candidate in candidates) candidate.id: candidate};
  unique[current.id] = current;
  return unique.values.toList()..sort((a, b) {
    final byScore = (b.resumeScore ?? -1).compareTo(a.resumeScore ?? -1);
    if (byScore != 0) return byScore;
    final byDate = a.createdAt.compareTo(b.createdAt);
    return byDate == 0 ? a.id.compareTo(b.id) : byDate;
  });
}
