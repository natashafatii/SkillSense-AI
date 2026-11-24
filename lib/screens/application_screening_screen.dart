import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/services.dart';
import '../models/resume_detail.dart';
import '../models/screening_assessment.dart';
import '../services/resume_download.dart';
import '../widgets/screening_visuals.dart';
import 'package:dio/dio.dart';
import '../models/api_contract.dart';
import '../services/api_exception.dart';
import '../services/foreground_poller.dart';
import 'package:flutter/material.dart';
import 'hr/recruitment_review_screen.dart';
import '../widgets/recruiter_top_bar.dart';
import 'package:file_picker/file_picker.dart';
import '../models/application.dart';
import '../services/application_service.dart';
import '../services/resume_service.dart';
import '../services/session_scope.dart';
import '../services/auth_service.dart';
import '../widgets/question_preparation_panel.dart';
import '../widgets/candidate_scaffold.dart';
import 'candidate/widgets/candidate_application_summary.dart';

part 'application_screening_layout.dart';
part 'application_screening_outcome.dart';
part 'application_screening_evidence.dart';

/// Application-owned progress and screening actions, shared by both roles.
class ApplicationScreeningScreen extends StatefulWidget {
  final String applicationId;
  final String Function()? roleProvider;
  final Future<Application> Function(String id)? loadApplication;
  final Future<Application> Function(
    Application app,
    String action,
    String reason,
  )?
  performAction;
  const ApplicationScreeningScreen({
    super.key,
    required this.applicationId,
    this.loadApplication,
    this.roleProvider,
    this.performAction,
  });
  @override
  State<ApplicationScreeningScreen> createState() =>
      _ApplicationScreeningScreenState();
}

class _ApplicationScreeningScreenState
    extends State<ApplicationScreeningScreen> {
  Application? _app;
  String? _error;
  bool _busy = false;
  String get _role => widget.roleProvider?.call() ?? AuthService.getUserRole();
  bool get _recruiter => _role == 'RECRUITER';
  late final ForegroundPoller<Application> _poller;
  bool _reviewRequired = false;
  bool _fresh = false;
  String? _replacementResumeId;
  final _reason = TextEditingController();
  final _session = SessionScope.generation;
  Future<Application> _read(CancelToken token) =>
      widget.loadApplication?.call(widget.applicationId) ??
      ApplicationService.getApplication(
        widget.applicationId,
        cancelToken: token,
      );
  void _accept(Application app) {
    if (!mounted || _session != SessionScope.generation) return;
    setState(() {
      _app = app;
      _error = null;
      _fresh = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _poller = ForegroundPoller(
      read: _read,
      isVisible: () => mounted && ModalRoute.of(context)?.isCurrent != false,
      isPending: (app) =>
          isPendingWorkflowState(app.assessment?['status']?.toString() ?? ''),
      onData: _accept,
      onStopped: (_) {
        if (mounted &&
            isPendingWorkflowState(
              _app?.assessment?['status']?.toString() ?? '',
            )) {
          setState(() => _error = 'Still processing. Refresh to check again.');
        }
      },
    );
    SessionScope.invalidations.addListener(_clearSession);
    _load();
  }

  void _clearSession() {
    _poller.stop();
    _reason.clear();
    _replacementResumeId = null;
    if (mounted) {
      setState(() {
        _app = null;
        _fresh = false;
        _error = 'Account session changed. Reopen the application.';
      });
    }
  }

  @override
  void dispose() {
    _poller.dispose();
    SessionScope.invalidations.removeListener(_clearSession);
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _poller.stop();
    try {
      final app =
          await (widget.loadApplication?.call(widget.applicationId) ??
              ApplicationService.getApplication(widget.applicationId));
      if (!mounted || _session != SessionScope.generation) return;
      setState(() {
        _app = app;
        _error = null;
      });
      _fresh = true;
      if (isPendingWorkflowState(app.assessment?['status']?.toString() ?? '')) {
        _poller.start();
      }
    } catch (error) {
      if (mounted && _session == SessionScope.generation) {
        setState(() {
          _error = '$error';
          _fresh = false;
          if (error is ApiException && error.accessUnavailable) _app = null;
        });
      }
    }
  }

  Future<void> _act(String action) async {
    final app = _app;
    if (app == null ||
        _busy ||
        _reviewRequired ||
        _session != SessionScope.generation) {
      return;
    }
    if (!app.allowedActions.contains(action) ||
        !const {
          'shortlist',
          'reject',
          'retry-screening',
          'rescreen',
        }.contains(action)) {
      return;
    }
    if (const {'shortlist', 'reject'}.contains(action) &&
        _reason.text.trim().isEmpty) {
      setState(
        () => _error = 'Enter a reason describing your evidence review.',
      );
      return;
    }
    if (!_recruiter && action != 'retry-screening') return;
    if (action == 'retry-screening' &&
        (app.screening?.recoveryAction == 'WAIT' ||
            (!_recruiter &&
                app.screening?.recoveryAction == 'CONTACT_SUPPORT'))) {
      setState(
        () => _error = 'Follow the server recovery guidance before retrying.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _poller.stop();
    try {
      String? resumeId = _replacementResumeId;
      if (action == 'retry-screening' &&
          app.assessment?['recovery_action'] == 'REPLACE_RESUME' &&
          !_recruiter &&
          _replacementResumeId == null) {
        final consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace resume'),
            content: const Text(
              'Choose a readable PDF or DOCX. Its text will be sent to Google Gemini for parsing and screening. Do you consent?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Agree and choose file'),
              ),
            ],
          ),
        );
        if (consent != true) return;
        final selection = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'docx'],
          withData: true,
        );
        if (selection == null) return;
        final file = selection.files.single;
        if (file.bytes == null) {
          throw StateError('Could not read the selected file.');
        }
        ApplicationService.validateResume(file.name, file.bytes!);
        final uploaded = await ResumeService.uploadResume(
          fileBytes: file.bytes!,
          fileName: file.name,
        );
        if (!mounted || _session != SessionScope.generation) return;
        resumeId = uploaded['id'] as String?;
        _replacementResumeId = resumeId;
        if (resumeId == null || resumeId.isEmpty) {
          throw const FormatException(
            'Upload did not return a resume identity.',
          );
        }
      }
      final updated =
          await (widget.performAction?.call(app, action, _reason.text.trim()) ??
              ApplicationService.screeningAction(
                app,
                action,
                reason: _reason.text.trim(),
                resumeId: resumeId,
                consent: resumeId != null,
              ));
      if (!mounted || _session != SessionScope.generation) return;
      setState(() {
        _app = updated;
        _reason.clear();
        _replacementResumeId = null;
      });
      await _load();
    } catch (error) {
      if (error is ApiException && error.requiresStateRefresh) {
        _reviewRequired = true;
      }
      // Preserve the reason while refreshing; explicit review gates resubmission.
      await _load();
      if (mounted) {
        setState(
          () => _error = error is ApiException ? error.message : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canRecruiterAct(String action) =>
      !_busy &&
      !_reviewRequired &&
      _fresh &&
      _app?.status != ApplicationStatus.unknown &&
      (action != 'retry-screening' ||
          !{
            'WAIT',
            'REPLACE_RESUME',
          }.contains(_app?.assessment?['recovery_action']));

  Future<void> _openRecruiterRoute(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _openScreeningSchedule(Application app) async {
    await Navigator.of(context).pushNamed(
      '/recruiter/schedule-interview',
      arguments: {'jobId': app.job, 'applicationId': app.id},
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (!_recruiter) return _buildCandidateView(app);
    return _ScreeningWorkspace(
      app: app,
      error: _error,
      busy: _busy,
      needsReview: _reviewRequired,
      acknowledge: _busy || !_fresh
          ? null
          : () => setState(() => _reviewRequired = false),
      refresh: _busy ? null : _load,
      reason: _reason,
      action: _act,
      canAct: _canRecruiterAct,
      interview: () {
        if (app != null) {
          _openRecruiterRoute(
            RecruitmentReviewScreen(
              applicationId: app.id,
              compactScreening: true,
            ),
          );
        }
      },
      schedule: () {
        if (app != null && app.eligibleForInterview && !_busy) {
          _openScreeningSchedule(app);
        }
      },
    );
  }

  Widget _buildCandidateView(Application? app) {
    final canRetry =
        app != null &&
        app.allowedActions.contains('retry-screening') &&
        !{'WAIT', 'CONTACT_SUPPORT'}.contains(app.screening?.recoveryAction);
    return CandidateScaffold(
      currentRoute: '/candidate/applications',
      body: Column(
        children: [
          RecruiterTopBar(pageTitle: 'My application', candidate: true),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).size.width < 900 ? 164 : 32,
                  ),
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _busy ? null : _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!),
                      ),
                    if (app == null && _error == null)
                      const Center(child: CircularProgressIndicator()),
                    if (app != null)
                      CandidateApplicationSummary(application: app),
                    if (_reviewRequired)
                      TextButton(
                        onPressed: _busy || !_fresh
                            ? null
                            : () => setState(() => _reviewRequired = false),
                        child: const Text(
                          'I reviewed the refreshed application',
                        ),
                      ),
                    if (canRetry)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FilledButton(
                          onPressed:
                              _busy ||
                                  _reviewRequired ||
                                  !_fresh ||
                                  app.status == ApplicationStatus.unknown
                              ? null
                              : () => _act('retry-screening'),
                          child: Text(
                            app.screening?.recoveryAction == 'REPLACE_RESUME'
                                ? 'Replace resume and retry'
                                : 'Retry resume processing',
                          ),
                        ),
                      ),
                    if (_busy) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
