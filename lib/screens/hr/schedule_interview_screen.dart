import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../models/question_set.dart';
import '../../services/api_exception.dart';
import '../../services/application_service.dart';
import '../../services/auth_service.dart';
import '../../services/interview_service.dart';
import '../../services/job_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/question_preparation_panel.dart';
import '../../widgets/recruiter_button_style.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import '../../widgets/recruiter_scaffold.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/screening_visuals.dart';
import 'recruitment_review_screen.dart';

part 'schedule_interview_layout.dart';
part 'compact_screening_schedule.dart';

/// Recruiter scheduling console for shortlisted applications.
class ScheduleInterviewScreen extends StatefulWidget {
  final String? jobId;
  final String? applicationId;
  final bool compactScreening;
  final Dio? questionClient;
  final Dio? interviewClient;
  final Future<List<Job>> Function()? loadJobs;
  final Future<List<Application>> Function(String jobId)? loadForJob;
  final Future<Application> Function(String applicationId)? loadApplication;
  final Future<List<Interview>> Function(String jobId)? loadBooked;
  final Future<Interview> Function(
    String applicationId,
    DateTime scheduledAt,
    String questionSetId,
    int expectedRevision,
  )?
  sendInvite;

  const ScheduleInterviewScreen({
    super.key,
    this.jobId,
    this.applicationId,
    this.compactScreening = false,
    this.questionClient,
    this.interviewClient,
    this.loadJobs,
    this.loadForJob,
    this.loadApplication,
    this.loadBooked,
    this.sendInvite,
  });

  @override
  State<ScheduleInterviewScreen> createState() =>
      _ScheduleInterviewScreenState();
}

class _ScheduleInterviewScreenState extends State<ScheduleInterviewScreen> {
  final _openDropdown = ValueNotifier<Key?>(null);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _ink => _dark ? _colors.onSurface : const Color(0xFF201F2B);
  Color get _muted =>
      _dark ? _colors.onSurfaceVariant : const Color(0xFF575C70);
  Color get _edge => _dark
      ? _colors.outlineVariant.withValues(alpha: .55)
      : const Color(0xFFDCE2ED);
  Color get _surface => _dark ? _colors.surface : Colors.white;
  Color get _blue => _dark ? _colors.primary : const Color(0xFF1A368A);
  final _reviewKey = GlobalKey();
  bool _reviewExpanded = false;
  static const _recruiterOffset = Duration(hours: 5);
  static const _zone = 'Pakistan Standard Time · UTC+05:00';

  List<Job> _jobs = [];
  List<Application> _awaiting = [];
  List<Interview>? _booked;
  final Set<String> _scheduledIds = {};
  final Map<String, String> _rowErrors = {};
  String? _jobId;
  String? _applicationId;
  String? _busyApplicationId;
  String? _error;
  bool _loading = true;
  int _request = 0;
  final _session = SessionScope.generation;
  final Set<String> _scheduleReviewRequired = {};
  int _questionReload = 0;
  bool _flexible = false;
  bool _notifyInApp = true;
  bool _notifyEmail = true;
  bool get _hasDelivery => _notifyInApp || _notifyEmail;
  String get _timingType =>
      _flexible ? 'Flexible deadline' : 'Specific date & time';
  String get _dateField => _flexible ? 'Deadline date' : 'Interview date';
  String get _timeField => _flexible ? 'Deadline time' : 'Interview time';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  DateTime? get _selectedSlot {
    final day = _selectedDate;
    final time = _selectedTime;
    if (day == null || time == null) return null;
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    ).subtract(_recruiterOffset);
  }

  DateTime _inRecruiterZone(DateTime instant) =>
      instant.toUtc().add(_recruiterOffset);

  Interview? _interview;
  List<InterviewQuestion> _questions = [];
  final Map<String, TextEditingController> _questionTexts = {};
  bool _questionsWorking = false;
  String? _questionError;
  String? _questionNotice;
  String? _approvedQuestionApplication;
  String? _approvedQuestionSet;
  int? _approvedQuestionRevision;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    _applicationId = widget.applicationId;
    SessionScope.invalidations.addListener(_clearSession);
    _loadJobs();
  }

  void _clearSession() {
    _request++;
    if (!mounted) return;
    setState(() {
      _jobs = [];
      _awaiting = [];
      _booked = null;
      _questions = [];
      _interview = null;
      _applicationId = null;
      _selectedDate = null;
      _selectedTime = null;
      _approvedQuestionApplication = null;
      _approvedQuestionSet = null;
      _approvedQuestionRevision = null;
      _error = 'Account session changed. Reopen scheduling.';
      _loading = false;
      _flexible = false;
      _notifyInApp = true;
      _notifyEmail = true;
      _reviewExpanded = false;
    });
    for (final controller in _questionTexts.values) {
      controller.clear();
    }
  }

  @override
  void didUpdateWidget(covariant ScheduleInterviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId) {
      _jobId = widget.jobId;
      _applicationId = widget.applicationId;
      _selectedDate = null;
      _selectedTime = null;
      _loadJobs();
    }
  }

  @override
  void dispose() {
    _openDropdown.dispose();
    SessionScope.invalidations.removeListener(_clearSession);
    for (final controller in _questionTexts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadJobs() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requested = _jobId;
      final jobs = List<Job>.from(
        await (widget.loadJobs?.call() ??
            (requested == null
                ? JobService.listAllJobs(status: JobStatus.active)
                : JobService.getJob(requested).then((job) => [job]))),
      );
      if (!mounted || request != _request) return;
      if (requested != null &&
          widget.loadJobs != null &&
          !jobs.any((job) => job.id == requested)) {
        jobs.add(await JobService.getJob(requested));
        if (!mounted || request != _request) return;
      }
      setState(() {
        _jobs = jobs;
        _jobId = requested ?? (jobs.length == 1 ? jobs.first.id : null);
        _awaiting = [];
        _booked = [];
        if (_jobId == null) _loading = false;
      });
      if (_jobId != null) await _loadAwaiting();
    } catch (error) {
      if (!mounted || request != _request) return;
      if (await _handleUnauthorized(error)) return;
      setState(() {
        _loading = false;
        _error = _friendlyLoadError(error);
      });
    }
  }

  Future<List<Interview>?> _loadBookings(String jobId) async {
    try {
      final interviews =
          await (widget.loadBooked?.call(jobId) ??
              InterviewService.listForJob(
                jobId,
                client: widget.interviewClient,
              ));
      return interviews
          .where(
            (interview) =>
                interview.scheduledAt != null &&
                const {'SCHEDULED', 'LIVE'}.contains(interview.status),
          )
          .toList();
    } on ApiException catch (error) {
      if (error.statusCode == 401) rethrow;
      return null;
    }
  }

  Future<void> _loadAwaiting() async {
    final request = ++_request;
    final jobId = _jobId;
    if (jobId == null || jobId.isEmpty) {
      setState(() {
        _loading = false;
        _booked = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _awaiting = [];
      _booked = null;
    });
    try {
      final results = await Future.wait<Object?>([
        widget.loadForJob?.call(jobId) ??
            ApplicationService.listAllForJob(jobId, eligibleForInterview: true),
        _loadBookings(jobId),
      ]);
      if (!mounted || request != _request || jobId != _jobId) return;
      final applications = results[0] as List<Application>;
      final booked = results[1] as List<Interview>?;
      final shortlisted =
          applications
              .where(
                (app) =>
                    app.job == jobId &&
                    _isShortlisted(app) &&
                    !_scheduledIds.contains(app.id),
              )
              .toList()
            ..sort(
              (a, b) =>
                  b.updatedAt?.compareTo(a.updatedAt ?? a.createdAt) ??
                  b.createdAt.compareTo(a.createdAt),
            );
      final requestedApplication =
          _applicationId ??
          (widget.compactScreening && _interview == null
              ? widget.applicationId
              : null);
      if (requestedApplication != null &&
          !shortlisted.any((app) => app.id == requestedApplication)) {
        final id = requestedApplication;
        // Keep the loaded job selector usable while a deep-linked detail waits.
        setState(() {
          _awaiting = shortlisted;
          _booked = booked;
          _loading = false;
        });
        final selected =
            await (widget.loadApplication?.call(id) ??
                ApplicationService.getApplication(id));
        if (!mounted || request != _request || jobId != _jobId) return;
        if (selected.id == id &&
            selected.job == jobId &&
            _isShortlisted(selected) &&
            !_scheduledIds.contains(id)) {
          shortlisted.add(selected);
        }
      }
      setState(() {
        _awaiting = shortlisted;
        _booked = booked;
        if (shortlisted.any((app) => app.id == requestedApplication)) {
          _applicationId = requestedApplication;
        } else {
          _applicationId = !widget.compactScreening && shortlisted.length == 1
              ? shortlisted.single.id
              : null;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request || jobId != _jobId) return;
      if (await _handleUnauthorized(error)) return;
      setState(() {
        _error = _friendlyLoadError(error);
        _loading = false;
      });
    }
  }

  bool _isShortlisted(Application app) =>
      const {
        'SHORTLISTED',
        'SCREENED',
      }.contains((app.rawStatus ?? app.status.value).toUpperCase()) &&
      app.eligibleForInterview;

  String _friendlyLoadError(Object error) {
    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          return 'Select a job to schedule interviews.';
        case 403:
          return "You're not authorized.";
        case 404:
          return 'Job not found.';
      }
    }
    return 'Something went wrong. Try again.';
  }

  Future<bool> _handleUnauthorized(Object error) async {
    if (error is! ApiException || error.statusCode != 401) return false;
    try {
      await AuthService.signOut();
    } catch (_) {
      // Navigate even if the identity provider already ended the session.
    }
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
    return true;
  }

  void _changeJob(String? id) {
    if (id == null || id == _jobId) return;
    setState(() {
      _jobId = id;
      _applicationId = null;
      _approvedQuestionApplication = null;
      _approvedQuestionSet = null;
      _approvedQuestionRevision = null;
      _selectedDate = null;
      _selectedTime = null;
      _rowErrors.clear();
      _interview = null;
      _reviewExpanded = false;
    });
    _loadAwaiting();
  }

  bool _taken(DateTime slot) =>
      _booked?.any((interview) {
        final at = interview.scheduledAt;
        return at != null &&
            at.millisecondsSinceEpoch ~/ 60000 ==
                slot.millisecondsSinceEpoch ~/ 60000;
      }) ??
      false;

  String? get _timingError {
    final slot = _selectedSlot;
    if (slot == null) return null;
    if (!slot.isAfter(DateTime.now())) {
      return 'Choose a date and time in the future.';
    }
    if (!_flexible && _taken(slot)) {
      return 'An interview is already booked at this time. Choose another time.';
    }
    return null;
  }

  bool _canSchedule(Application app) =>
      _isShortlisted(app) &&
      !_scheduleReviewRequired.contains(app.id) &&
      _approvedQuestionApplication == app.id &&
      _approvedQuestionSet != null &&
      _approvedQuestionRevision != null;

  Future<void> _sendInvite(Application app) async {
    if (_busyApplicationId != null || _session != SessionScope.generation) {
      return;
    }
    if (!_canSchedule(app)) {
      setState(
        () => _rowErrors[app.id] =
            'Review and approve the current question revision before scheduling.',
      );
      return;
    }
    final setId = _approvedQuestionSet!, revision = _approvedQuestionRevision!;
    final slot = _selectedSlot;
    if (slot == null ||
        (!_flexible && _booked == null) ||
        _timingError != null ||
        !_hasDelivery) {
      setState(() => _rowErrors[app.id] = 'Choose an available future slot.');
      return;
    }
    if (app.job != _jobId || !_isShortlisted(app)) {
      setState(
        () => _rowErrors[app.id] = 'This application is no longer shortlisted.',
      );
      return;
    }
    setState(() {
      _busyApplicationId = app.id;
      _rowErrors.remove(app.id);
    });
    try {
      final interview =
          // Approval remains a server-enforced gate; these are the reviewed revision.
          await ((!_flexible && _notifyInApp && _notifyEmail
                  ? widget.sendInvite?.call(app.id, slot, setId, revision)
                  : null) ??
              InterviewService.schedule(
                client: widget.interviewClient,
                applicationId: app.id,
                scheduledAt: _flexible ? null : slot,
                deadlineAt: _flexible ? slot : null,
                notifyInApp: _notifyInApp,
                notifyEmail: _notifyEmail,
                questionSetId: setId,
                expectedRevision: revision,
              ));
      if (!mounted ||
          app.job != _jobId ||
          _session != SessionScope.generation) {
        return;
      }
      setState(() {
        _interview = interview;
        _scheduledIds.add(app.id);
        _awaiting.removeWhere((item) => item.id == app.id);
        _booked = [...?_booked, interview];
        _applicationId = null;
        _selectedDate = null;
        _selectedTime = null;
        _reviewExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview invitation scheduled.')),
      );
      await _loadAwaiting();
    } catch (error) {
      if (!mounted) return;
      if (await _handleUnauthorized(error)) return;
      if (error is ApiException && error.requiresStateRefresh) {
        _scheduleReviewRequired.add(app.id);
        _approvedQuestionApplication = null;
        _approvedQuestionSet = null;
        _approvedQuestionRevision = null;
        _questionReload++;
        try {
          await (widget.loadApplication?.call(app.id) ??
              ApplicationService.getApplication(app.id));
          await _loadAwaiting();
        } catch (_) {
          /* Keep submission blocked until refreshed and reviewed. */
        }
      }
      if (!mounted) return;
      setState(() {
        _rowErrors[app.id] = switch (error) {
          ApiException(statusCode: 403) =>
            "You're not authorized to schedule this interview.",
          ApiException(statusCode: 400, :final message) => message,
          ApiException(:final message) => message,
          _ => 'Could not schedule this interview: $error',
        };
      });
    } finally {
      if (mounted) setState(() => _busyApplicationId = null);
    }
  }

  Future<void> _refreshQuestions() async {
    final id = _interview?.id;
    if (id == null) return;
    setState(() {
      _questionsWorking = true;
      _questionError = null;
    });
    try {
      final questions = await InterviewService.getQuestions(id);
      if (!mounted || _interview?.id != id) return;
      for (final controller in _questionTexts.values) {
        controller.dispose();
      }
      _questionTexts.clear();
      for (final question in questions) {
        _questionTexts[question.id] = TextEditingController(
          text: question.text,
        );
      }
      setState(() {
        _questions = questions;
        _questionNotice = questions.isEmpty
            ? 'No scheduled questions are available.'
            : 'These questions are frozen for the scheduled interview.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _questionError = 'Could not load questions: $error');
      }
    } finally {
      if (mounted) setState(() => _questionsWorking = false);
    }
  }

  Application? get _selectedApplication =>
      _awaiting.where((app) => app.id == _applicationId).firstOrNull;

  void _updateSchedule(VoidCallback change) => setState(change);

  void _recordQuestionApproval(
    String applicationId,
    String? setId,
    int? revision,
  ) {
    if (!mounted ||
        _applicationId != applicationId ||
        _session != SessionScope.generation) {
      return;
    }
    setState(() {
      _approvedQuestionApplication = setId == null ? null : applicationId;
      _approvedQuestionSet = setId;
      _approvedQuestionRevision = revision;
      if (setId != null) _scheduleReviewRequired.remove(applicationId);
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.compactScreening ? _buildCompactSchedule() : _buildSchedule();

  String get _shortlistLabel => switch (_awaiting.length) {
    0 => 'No shortlisted candidates available',
    1 => '1 shortlisted candidate',
    final count => '$count shortlisted candidates',
  };

  Widget _dropdown({
    required Key key,
    required String? value,
    required String hint,
    required List<({String id, String title, String subtitle})> items,
    required ValueChanged<String?>? onChanged,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final enabled = items.isNotEmpty && onChanged != null;
      final selected = items.where((item) => item.id == value).firstOrNull;
      final activeInk = _dark
          ? _colors.onPrimaryContainer
          : const Color(0xFF1A368A);
      final activeFill = _dark
          ? _colors.primaryContainer
          : const Color(0xFFEDF2FC);
      final hoverFill = _dark
          ? _colors.surfaceContainerHighest
          : const Color(0xFFF5F7FA);
      return MenuAnchor(
        alignmentOffset: const Offset(0, 8),
        onOpen: () => _openDropdown.value = key,
        onClose: () {
          if (_openDropdown.value == key) _openDropdown.value = null;
        },
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(
            _colors.shadow.withValues(alpha: .18),
          ),
          elevation: const WidgetStatePropertyAll(5),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 260)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: _edge),
            ),
          ),
        ),
        menuChildren: [
          for (final item in items)
            Semantics(
              selected: item.id == value,
              child: MenuItemButton(
                onPressed: enabled ? () => onChanged(item.id) : null,
                style: ButtonStyle(
                  alignment: AlignmentDirectional.centerStart,
                  minimumSize: WidgetStatePropertyAll(
                    Size(
                      (constraints.maxWidth - 12)
                          .clamp(0.0, double.infinity)
                          .toDouble(),
                      44,
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  backgroundColor: WidgetStatePropertyAll(
                    item.id == value ? activeFill : Colors.transparent,
                  ),
                  overlayColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        item.id != value &&
                            (states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused))
                        ? hoverFill
                        : null,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                trailingIcon: item.id == value
                    ? Icon(Icons.check, size: 18, color: activeInk)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.id == value ? activeInk : _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (item.subtitle.trim().isNotEmpty)
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.id == value && !_dark
                              ? const Color(0xFF43536E)
                              : _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        builder: (context, controller, _) => ValueListenableBuilder<Key?>(
          valueListenable: _openDropdown,
          builder: (context, openKey, _) {
            final open = openKey == key;
            final focusColor = _dark
                ? _colors.primary
                : const Color(0xFFB4C7FA);
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                boxShadow: open
                    ? [
                        BoxShadow(
                          color: focusColor.withValues(alpha: .7),
                          spreadRadius: 3,
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: OutlinedButton(
                key: key,
                onPressed: enabled
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  side: BorderSide(color: open ? _blue : _fieldEdge),
                  foregroundColor: selected == null ? _muted : _ink,
                  backgroundColor: _surface,
                  disabledBackgroundColor: _subtle,
                  disabledForegroundColor: _muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected?.title ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _type(14, weight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RotatedBox(
                      quarterTurns: open ? 2 : 0,
                      child: _icon(_collapseArrow, size: 18, color: _muted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Future<void> _reviewAndSend() async {
    final app = _selectedApplication;
    if (app == null) return;
    if (!_canSchedule(app)) {
      setState(() => _reviewExpanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final reviewContext = _reviewKey.currentContext;
        if (reviewContext != null) {
          Scrollable.ensureVisible(
            reviewContext,
            duration: const Duration(milliseconds: 250),
            alignment: 0.1,
          );
        }
      });
      return;
    }
    await _confirmInvite();
  }

  Future<void> _confirmInvite() async {
    final app = _selectedApplication, slot = _selectedSlot;
    if (app == null || slot == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text('Review & send invitation', style: TextStyle(color: _ink)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryRow('Candidate', _candidateName(app)),
                _summaryRow(_dateField, _dateLabel(_inRecruiterZone(slot))),
                _summaryRow(
                  _timeField,
                  '${_timeLabel(_inRecruiterZone(slot))} PKT',
                ),
                _summaryRow('Invitation type', _timingType),
                _summaryRow(
                  'Send via',
                  [
                    if (_notifyInApp) 'In-app',
                    if (_notifyEmail) 'Email',
                  ].join(' and '),
                ),
                const SizedBox(height: 16),
                _body(
                  'Confirm to schedule this interview using the approved question revision and notify the candidate through the selected channels.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: RecruiterButtonStyle.primary(FilledButton.styleFrom()),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send invitation'),
          ),
        ],
      ),
    );
    if (approved == true &&
        mounted &&
        _applicationId == app.id &&
        _selectedSlot == slot) {
      await _sendInvite(app);
    }
  }

  void _selectForReview(Application app) {
    if (_applicationId == app.id) return;
    setState(() {
      _applicationId = app.id;
      _approvedQuestionApplication = null;
      _approvedQuestionSet = null;
      _approvedQuestionRevision = null;
      _reviewExpanded = false;
    });
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

  String _scoreText(double score) => score == score.roundToDouble()
      ? score.round().toString()
      : score.toStringAsFixed(1);

  Widget _questionPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Scheduled interview questions'),
        TextButton(
          onPressed: () async {
            final interview = _interview!;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecruitmentReviewScreen(
                  applicationId: interview.applicationId,
                  interviewId: interview.id,
                ),
              ),
            );
            if (!mounted || _interview?.id != interview.id) return;
            try {
              final refreshed = await InterviewService.getInterview(
                interview.id,
                client: widget.interviewClient,
                role: 'RECRUITER',
              );
              if (!mounted || _interview?.id != interview.id) return;
              setState(() => _interview = refreshed);
              if (_jobId case final jobId?) {
                final bookings = await _loadBookings(jobId);
                if (mounted &&
                    _jobId == jobId &&
                    _interview?.id == interview.id) {
                  setState(() => _booked = bookings);
                }
              }
            } catch (_) {
              // Frozen questions can still be refreshed if the timing read fails.
            }
            if (mounted && _interview?.id == interview.id) _refreshQuestions();
          },
          child: Text(
            _interview!.isFlexible
                ? 'Review evidence or extend the deadline'
                : 'Review evidence, reschedule or schedule another attempt',
          ),
        ),
        Text(
          'Workflow: ${_interview!.workflowState} · ${_interview!.isFlexible ? 'Start by ' : ''}${_interview!.timingAt?.toLocal()} ${DateTime.now().timeZoneName}',
        ),
        Text('Preparation: ${_interview!.questionPreparationMode}'),
        if (_interview!.questionFallbackReason.isNotEmpty)
          Text('Reason: ${_interview!.questionFallbackReason}'),
        const SizedBox(height: 7),
        Text(
          'Interview ID: ${_interview!.id}',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            color: _muted,
            fontSize: 10,
          ),
        ),
        if (_questionNotice != null) Text(_questionNotice!),
        if (_questionError != null)
          Text(
            _questionError!,
            style: const TextStyle(color: Color(0xFFD64255)),
          ),
        TextButton(
          onPressed: _questionsWorking ? null : _refreshQuestions,
          child: const Text('Refresh frozen questions'),
        ),
        for (final question in _questions)
          TextField(
            controller: _questionTexts[question.id],
            readOnly: true,
            maxLines: 2,
            decoration: InputDecoration(
              labelText:
                  'Question ${question.id} · ${question.source}${question.isApproved ? ' · approved' : ' · pending approval'}',
            ),
          ),
      ],
    ),
  );
}
