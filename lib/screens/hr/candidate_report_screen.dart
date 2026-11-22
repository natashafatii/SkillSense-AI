import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/api_contract.dart';
import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../models/resume_detail.dart';
import '../../models/recruitment_evidence.dart';
import '../../models/screening_assessment.dart';
import '../../services/api_exception.dart';
import '../../services/app_theme_controller.dart';
import '../../services/application_service.dart';
import '../../services/foreground_poller.dart';
import '../../services/job_service.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../services/resume_download.dart';
import '../../services/resume_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/notification_unread_scope.dart';
import '../../widgets/question_preparation_panel.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'recruitment_review_screen.dart';
import 'schedule_interview_screen.dart';

part 'candidate_report_content.dart';
part 'candidate_report_workspace.dart';
part 'candidate_report_chrome.dart';
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
  late final AppLifecycleListener _lifecycle;
  CancelToken? _request;
  CancelToken? _interviewRequest;
  Future<RecruiterInterview?>? _interview;
  late final ForegroundPoller<_InterviewEvidence> _evidencePoller;
  _InterviewEvidence? _evidence;
  bool _evidenceLoading = false;
  bool _evidenceError = false;
  final _overviewKey = GlobalKey();
  final _decisionKey = GlobalKey();
  final _screeningKey = GlobalKey();
  final _interviewKey = GlobalKey();
  final _answersKey = GlobalKey();
  final _scroll = ScrollController();
  int _section = 0;
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
                  _data?.application.status == ApplicationStatus.inProgress
                  ? 'The interview is still in progress. Refresh to check again.'
                  : 'Processing is still pending. Refresh to check again.',
            );
          }
        }
      },
    );
    _evidencePoller = ForegroundPoller(
      read: (token) async => _readEvidence((await _interview!)!, token),
      isVisible: () =>
          mounted && _signedIn && ModalRoute.of(context)?.isCurrent != false,
      isPending: (data) => data.pending,
      onData: (data) => setState(() => _evidence = data),
      onStopped: (error) {
        if (!mounted || !_signedIn || error == null) return;
        setState(() {
          _evidenceError = true;
          if (error is ApiException && error.accessUnavailable) {
            _evidence = null;
          }
        });
      },
    );
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_signedIn &&
            _data != null &&
            !_loading &&
            ModalRoute.of(context)?.isCurrent == true) {
          _load(refreshCandidates: true);
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
    _lifecycle.dispose();
    _evidencePoller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clearReport() {
    _request?.cancel();
    _interviewRequest?.cancel();
    _poller.stop();
    _request = null;
    _interviewRequest = null;
    _interview = null;
    _evidencePoller.stop();
    _evidence = null;
    _evidenceLoading = false;
    _evidenceError = false;
    _data = null;
    _error = null;
    _notice = null;
    _loading = false;
    _section = 0;
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
      data.assessment?.pending == true ||
      data.resume?.isPending == true ||
      data.application.status == ApplicationStatus.inProgress;

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
    _evidencePoller.stop();
    _evidence = null;
    _evidenceError = false;
    _evidenceLoading = true;
    _loadEvidence(_interview!, token);
  }

  Future<void> _loadEvidence(
    Future<RecruiterInterview?> attempt,
    CancelToken token,
  ) async {
    try {
      final interview = await attempt;
      if (token.isCancelled || !mounted || !_signedIn) return;
      if (interview == null || interview.status == 'SCHEDULED') return;
      final evidence = await _readEvidence(interview, token);
      if (token.isCancelled || !mounted || !_signedIn) return;
      setState(() => _evidence = evidence);
      if (evidence.pending) _evidencePoller.start();
    } catch (_) {
      if (!token.isCancelled && mounted && _signedIn) {
        setState(() => _evidenceError = true);
      }
    } finally {
      if (!token.isCancelled && mounted && _signedIn) {
        setState(() => _evidenceLoading = false);
      }
    }
  }

  Future<_InterviewEvidence> _readEvidence(
    RecruiterInterview interview,
    CancelToken token,
  ) async {
    final history = EvaluationHistory.fromJson(
      await _workflow.request(
        '/interviews/${Uri.encodeComponent(interview.id)}/evaluations/',
        cancelToken: token,
      ),
    );
    final evaluation = history.revisions.firstOrNull;
    TranscriptRevision? transcript;
    var transcriptUnavailable = false;
    if (evaluation != null &&
        evaluation.status == 'READY' &&
        (evaluation.answers.any((answer) => answer.evidence.isNotEmpty) ||
            evaluation.extraction?.questions.any(
                  (answer) => answer.followUpTurnIds.isNotEmpty,
                ) ==
                true)) {
      try {
        transcript = evaluation.frozenTranscript(
          TranscriptHistory.fromJson(
            await _workflow.request(
              '/interviews/${Uri.encodeComponent(interview.id)}/transcript-revisions/',
              cancelToken: token,
            ),
          ),
        );
        transcriptUnavailable = transcript == null;
      } catch (_) {
        transcriptUnavailable = true;
      }
    }
    return (
      evaluation: evaluation,
      transcript: transcript,
      transcriptUnavailable: transcriptUnavailable,
      pending:
          evaluation?.pending == true ||
          (evaluation == null && history.transcriptState == 'WAITING'),
    );
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
          _interviewRequest?.cancel();
          _evidencePoller.stop();
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
          service: _workflow,
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
    required _ReportPalette palette,
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
      return Semantics(
        label: label,
        child: DropdownMenu<String>(
          key: ValueKey((label, selection)),
          expandedInsets: EdgeInsets.zero,
          hintText: label == 'Job' ? 'Select a job' : 'Select an applicant',
          textStyle: _reportDisplay(
            context,
            AppType.bodySm,
          ).copyWith(color: palette.ink),
          initialSelection: selection,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 360,
          leadingIcon: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: _ReportGlyph(
              label == 'Job' ? _ReportIcon.job : _ReportIcon.person,
              color: palette.muted,
              size: 17,
            ),
          ),
          trailingIcon: _ReportGlyph(
            _ReportIcon.chevron,
            color: palette.accent,
          ),
          selectedTrailingIcon: RotatedBox(
            quarterTurns: 2,
            child: _ReportGlyph(_ReportIcon.chevron, color: palette.accent),
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(palette.paper),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: BorderSide(color: palette.border),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationThemeData(
            filled: true,
            isDense: true,
            fillColor: palette.field,
            hintStyle: _reportDisplay(
              context,
              AppType.caption,
            ).copyWith(color: palette.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: palette.blue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: palette.border),
            ),
          ),
          dropdownMenuEntries: [
            for (final row in rows)
              DropdownMenuEntry(value: id(row), label: title(row)),
          ],
          onSelected: onSelected,
        ),
      );
    },
  );

  Widget _selectors(double width, _ReportPalette palette) {
    final roles = _picker<Job>(
      label: 'Job',
      palette: palette,
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
      label: 'Applicant',
      palette: palette,
      future: candidates,
      selection: _applicationId,
      id: (app) => app.id,
      title: _candidateName,
      onSelected: _selectCandidate,
      retry: () => setState(() => _candidates = _loadCandidates(_jobId!)),
    );
    if (width <= 456) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [roles, const SizedBox(height: 8), applicants],
      );
    }
    return Row(
      children: [
        Expanded(child: roles),
        const SizedBox(width: 8),
        Expanded(child: applicants),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = _data?.application;
    final viewport = MediaQuery.sizeOf(context).width;
    final mobile = viewport < 900;
    final palette = _ReportPalette(context.isDarkTheme, context.typeStep);
    final body = Column(
      children: [
        _ReportCommandBar(
          palette: palette,
          candidate: app == null ? null : _candidateName(app),
          compact: viewport <= 480,
          mobile: mobile,
          section: _section,
          onSection: app != null ? _jumpToSection : null,
          onBack: widget.applicationId != null && Navigator.of(context).canPop()
              ? () => Navigator.of(context).maybePop()
              : null,
        ),
        if (_loading && _data != null)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = viewport <= 480
                  ? 12.0
                  : (viewport * .03).clamp(18.0, 42.0);
              final width = (constraints.maxWidth - gutter * 2).clamp(
                0.0,
                double.infinity,
              );
              final data = _data;
              final selectorWidth = _candidates == null ? 300.0 : 480.0;
              final title = Semantics(
                key: _overviewKey,
                header: true,
                child: Text(
                  'Candidate report',
                  style: context.text.headlineLarge,
                ),
              );
              return RefreshIndicator(
                onRefresh: () => _load(refreshCandidates: true),
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    (constraints.maxWidth - width) / 2,
                    23,
                    (constraints.maxWidth - width) / 2,
                    56,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_jobs != null && width >= 760)
                        Row(
                          children: [
                            Expanded(child: title),
                            SizedBox(
                              width: selectorWidth,
                              child: _selectors(selectorWidth, palette),
                            ),
                          ],
                        )
                      else ...[
                        title,
                        if (_jobs != null) ...[
                          const SizedBox(height: 12),
                          _selectors(width, palette),
                        ],
                      ],
                      const SizedBox(height: 15),
                      if (!_signedIn)
                        const _ReportMessage(
                          'Account session changed. Reopen the report.',
                        )
                      else if (data != null)
                        ..._report(data, palette, viewport)
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
                        const _ReportMessage(
                          'Select a role and candidate to open their report.',
                        ),
                    ],
                  ),
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
        textTheme: Theme.of(context).textTheme,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: palette.dark ? palette.accent : _accent,
          onPrimary: Colors.white,
          onSurface: palette.ink,
          surface: palette.paper,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.ink,
            backgroundColor: palette.field,
            side: BorderSide(color: palette.border),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            textStyle: AppType.button.style(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: palette.dark
                ? const Color(0xff4055e8)
                : const Color(0xff335cd0),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            textStyle: AppType.button.style(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DefaultTextStyle.merge(
          style: AppType.caption.style(context, color: palette.ink),
          child: SafeArea(bottom: !mobile, child: body),
        ),
      ),
    );
  }

  void _jumpToSection(int section) {
    final target = [
      _overviewKey,
      _screeningKey,
      _interviewKey,
      _answersKey,
      _decisionKey,
    ][section].currentContext;
    if (target == null) return;
    setState(() => _section = section);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    if (section == 0 && _scroll.hasClients) {
      if (duration == Duration.zero) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0, duration: duration, curve: Curves.easeOut);
      }
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: .025,
      duration: duration,
      curve: Curves.easeOut,
    );
  }

  List<Widget> _report(
    _ReportData data,
    _ReportPalette palette,
    double viewport,
  ) {
    final app = data.application;
    final assessment = data.assessment;
    final resume = data.resume;
    final fit = _SkillFit(assessment, resume);
    return [
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_notice case final notice?) _ReportMessage(notice),
      FutureBuilder<RecruiterInterview?>(
        future: _interview,
        builder: (context, attempt) => FutureBuilder<List<Application>>(
          future: _candidates,
          builder: (context, applicants) {
            final candidates = _rankedCandidates(
              applicants.data ?? const [],
              app,
            );
            final index = candidates.indexWhere(
              (candidate) => candidate.id == app.id,
            );
            final rank = app.resumeScore == null || index == -1
                ? null
                : candidates.indexWhere(
                        (candidate) => candidate.resumeScore == app.resumeScore,
                      ) +
                      1;
            final interview = attempt.connectionState == ConnectionState.done
                ? attempt.data
                : null;
            return _ReportWorkspace(
              palette: palette,
              data: data,
              decisionKey: _decisionKey,
              screeningKey: _screeningKey,
              interviewKey: _interviewKey,
              answersKey: _answersKey,
              viewport: viewport,
              interview: interview,
              evidence: _evidence,
              evidenceLoading: _evidenceLoading,
              evidenceError: _evidenceError,
              rank: rank,
              candidateCount: candidates.length,
              onPrevious: index > 0
                  ? () => _selectCandidate(candidates[index - 1].id)
                  : null,
              onNext: index >= 0 && index + 1 < candidates.length
                  ? () => _selectCandidate(candidates[index + 1].id)
                  : null,
              onReview: () => _openReview(app),
              onSchedule: app.eligibleForInterview
                  ? () => _schedule(app)
                  : null,
              onManage:
                  interview != null &&
                      app.status == ApplicationStatus.scheduled &&
                      interview.workflowState == 'SCHEDULED'
                  ? () => _openReview(app, interviewId: interview.id)
                  : null,
              onRefresh: _loading ? null : () => _load(refreshCandidates: true),
              onRetryEvidence: () => setState(() => _readInterview(app.id)),
              onDecision: () => _jumpToSection(4),
            );
          },
        ),
      ),
      const SizedBox(height: _gap),
      _ReportPanel(
        child: ExpansionTile(
          title: const Text('Application and resume details'),
          children: [
            _MatchCard(application: app, assessment: assessment, fit: fit),
            const SizedBox(height: _gap),
            FutureBuilder<RecruiterInterview?>(
              future: _interview,
              builder: (context, snapshot) {
                final current =
                    snapshot.connectionState == ConnectionState.done;
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
                  onSchedule: app.eligibleForInterview
                      ? () => _schedule(app)
                      : null,
                );
              },
            ),
          ],
        ),
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
