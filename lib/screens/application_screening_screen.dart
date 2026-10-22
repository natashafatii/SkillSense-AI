import '../widgets/mobile_edge_shadow_wrapper.dart';
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
import 'hr/schedule_interview_screen.dart';

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
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final assessment = app?.assessment;
    final evidence = app?.screening;
    final criteria = assessment?['criteria_results'] as List? ?? const [];
    final reasons = (assessment?['reasons'] as List? ?? const [])
        .join(', ')
        .replaceAll('_', ' ');
    const labels = {
      'shortlist': 'Shortlist',
      'reject': 'Reject',
      'retry-screening': 'Retry screening',
      'rescreen': 'Rescreen with current policy',
    };
    return Scaffold(
      appBar: _recruiter
          ? const PreferredSize(
              preferredSize: Size.fromHeight(58),
              child: RecruiterTopBar(pageTitle: 'Application screening'),
            )
          : AppBar(title: const Text('Application screening')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: MobileEdgeShadowWrapper(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Refresh application'),
                ),
                if (_reviewRequired)
                  TextButton(
                    onPressed: _busy || !_fresh
                        ? null
                        : () => setState(() => _reviewRequired = false),
                    child: const Text('I reviewed the refreshed application'),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (app == null && _error == null)
                  const Center(child: CircularProgressIndicator()),
                if (app != null) ...[
                  Text(
                    app.jobTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(app.candidateName ?? app.candidateEmail),
                  const SizedBox(height: 16),
                  Text(
                    'Application: ${(app.rawStatus ?? app.status.value).replaceAll('_', ' ')}',
                  ),
                  Text(
                    'Processing: ${assessment?['status'] ?? 'Awaiting assessment'}',
                  ),
                  if (assessment != null)
                    Text(
                      'Assessment ${assessment['revision']} · policy ${assessment['policy_version']}',
                    ),
                  Text(
                    'Eligibility: ${evidence?.eligibility ?? 'UNKNOWN'}${evidence?.eligibility == 'UNKNOWN' ? ' — requires review' : ''}',
                  ),
                  Text(
                    'Policy recommendation: ${evidence?.outcome ?? 'Unavailable'}',
                  ),
                  Text(
                    'Interview eligibility: ${app.eligibleForInterview ? 'Eligible stage, no existing interview' : 'Not currently eligible'}',
                  ),
                  Text('Recovery: ${evidence?.recoveryAction ?? 'WAIT'}'),
                  Text('Threshold: ${evidence?.threshold ?? 'Unavailable'}'),
                  if (app.resumeScore == null)
                    const Text('Screening match: Unavailable'),
                  if (_replacementResumeId != null)
                    Text('Selected replacement resume: $_replacementResumeId'),
                  if (app.resumeScore != null)
                    Text(
                      'Screening match: ${app.resumeScore!.toStringAsFixed(2)} / 100 · threshold ${evidence?.threshold ?? 'Unavailable'}',
                    ),
                  Text(
                    'Matched skills: ${evidence?.matchedSkills.join(', ') ?? 'Unavailable'}',
                  ),
                  Text(
                    'Missing skills: ${evidence?.missingSkills.join(', ') ?? 'Unavailable'}',
                  ),
                  if (reasons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(reasons),
                    ),
                  for (final row in criteria.whereType<Map>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${row['requirement']} — ${row['status']}'),
                      subtitle: Text('${row['evidence']}'),
                    ),
                  if ((assessment?['error_message'] ?? '')
                      .toString()
                      .isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${assessment!['error_message']}'),
                    ),
                  if (_recruiter &&
                      (app.allowedActions.contains('shortlist') ||
                          app.allowedActions.contains('reject')))
                    TextField(
                      controller: _reason,
                      maxLines: 3,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Reason for rejection or screening override',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final action in app.allowedActions.where(
                        (action) =>
                            labels.containsKey(action) &&
                            (_recruiter || action == 'retry-screening'),
                      ))
                        FilledButton(
                          onPressed:
                              _busy ||
                                  _reviewRequired ||
                                  !_fresh ||
                                  app.status == ApplicationStatus.unknown ||
                                  (action == 'retry-screening' &&
                                      ((evidence?.recoveryAction == 'WAIT' ||
                                              (!_recruiter &&
                                                  evidence?.recoveryAction ==
                                                      'CONTACT_SUPPORT')) ||
                                          (_recruiter &&
                                              evidence?.recoveryAction ==
                                                  'REPLACE_RESUME')))
                              ? null
                              : () => _act(action),
                          child: Text(labels[action] ?? action),
                        ),
                    ],
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_recruiter && app.history.isNotEmpty) ...[
                    const Text('Screening history'),
                    for (final event in app.history)
                      ListTile(
                        title: Text(
                          '${event['source'] ?? 'Unknown source'} · ${event['from_status']} → ${event['to_status']}',
                        ),
                        subtitle: Text('${event['reason'] ?? ''}'),
                      ),
                  ],
                  if (_recruiter)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecruitmentReviewScreen(
                                    applicationId: app.id,
                                  ),
                                ),
                              );
                              if (mounted) _load();
                            },
                      child: const Text(
                        'Review interview evidence, scores and decisions',
                      ),
                    ),
                  if (_recruiter && app.status == ApplicationStatus.screened)
                    QuestionPreparationPanel(
                      key: ValueKey('preparation-${app.id}'),
                      applicationId: app.id,
                      application: app,
                      onApprovalChanged: (_, _) {},
                    ),
                  if (_recruiter && app.eligibleForInterview)
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScheduleInterviewScreen(
                                    jobId: app.job,
                                    applicationId: app.id,
                                  ),
                                ),
                              );
                              if (mounted) _load();
                            },
                      child: const Text('Review questions and schedule'),
                    ),
                  if (app.eligibleForInterview)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        'Shortlisted and available for interview scheduling.',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
