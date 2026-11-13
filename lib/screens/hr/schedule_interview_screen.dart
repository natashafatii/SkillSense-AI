import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/question_preparation_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../services/api_exception.dart';
import '../../services/application_service.dart';
import '../../services/auth_service.dart';
import '../../services/interview_service.dart';
import '../../services/job_service.dart';
import '../../services/session_scope.dart';
import 'recruitment_review_screen.dart';

/// Recruiter scheduling console for shortlisted applications.
class ScheduleInterviewScreen extends StatefulWidget {
  final String? jobId;
  final String? applicationId;
  final Dio? questionClient;
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
    this.questionClient,
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
  Color get _ink => _colors.onSurface;
  Color get _muted => _colors.onSurfaceVariant;
  Color get _edge => _dark
      ? _colors.outlineVariant.withValues(alpha: .55)
      : const Color(0xFFE0E5ED);
  Color get _surface => _dark ? _colors.surface : Colors.white;
  Color get _blue => _colors.primary;
  Color get _activeFill => _colors.primaryContainer;
  final _message = TextEditingController();
  bool _inAppInvitation = true;
  bool _emailInvitation = true;
  final _reviewKey = GlobalKey();
  bool _reviewExpanded = false;
  static const _slots = <(int, int)>[
    (9, 0),
    (10, 30),
    (11, 30),
    (13, 0),
    (14, 0),
    (15, 30),
    (17, 0),
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
  late DateTime _monday;
  late int _selectedDay;
  DateTime? _selectedSlot;

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
    _monday = _weekStart(DateTime.now());
    _selectedDay = _initialDay();
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
      _approvedQuestionApplication = null;
      _approvedQuestionSet = null;
      _approvedQuestionRevision = null;
      _error = 'Account session changed. Reopen scheduling.';
      _message.clear();
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
      _selectedSlot = null;
      _loadJobs();
    }
  }

  @override
  void dispose() {
    _openDropdown.dispose();
    SessionScope.invalidations.removeListener(_clearSession);
    _message.dispose();
    for (final controller in _questionTexts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime _weekStart(DateTime now) {
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    if (now.weekday > 5 || (now.weekday == 5 && now.hour >= 17)) {
      return monday.add(const Duration(days: 7));
    }
    return monday;
  }

  int _initialDay() {
    final now = DateTime.now();
    for (var day = 0; day < 5; day++) {
      final date = _monday.add(Duration(days: day));
      final last = DateTime(date.year, date.month, date.day, 17);
      if (last.isAfter(now)) return day;
    }
    return 4;
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
      final results = await Future.wait<Object>([
        widget.loadForJob?.call(jobId) ??
            ApplicationService.listAllForJob(jobId, eligibleForInterview: true),
        widget.loadBooked?.call(jobId) ??
            InterviewService.listForJob(jobId, status: 'SCHEDULED'),
      ]);
      if (!mounted || request != _request || jobId != _jobId) return;
      final applications = results[0] as List<Application>;
      final booked = results[1] as List<Interview>;
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
      if (_applicationId != null &&
          !shortlisted.any((app) => app.id == _applicationId)) {
        final id = _applicationId!;
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
        if (!shortlisted.any((app) => app.id == _applicationId)) {
          _applicationId = shortlisted.length == 1
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
      _selectedSlot = null;
      _rowErrors.clear();
      _interview = null;
      _message.clear();
      _reviewExpanded = false;
    });
    _loadAwaiting();
  }

  DateTime _dateFor(int day) => _monday.add(Duration(days: day));

  DateTime _slotFor(int day, (int, int) time) {
    final date = _dateFor(day);
    return DateTime(date.year, date.month, date.day, time.$1, time.$2);
  }

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  bool _taken(DateTime slot) =>
      _booked?.any((interview) {
        final at = interview.scheduledAt?.toLocal();
        return at != null && _sameMinute(at, slot);
      }) ??
      false;

  int _bookedCount(int day) =>
      _booked?.where((interview) {
        final at = interview.scheduledAt?.toLocal();
        final date = _dateFor(day);
        return at != null &&
            at.year == date.year &&
            at.month == date.month &&
            at.day == date.day;
      }).length ??
      0;

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
        _booked == null ||
        _taken(slot) ||
        !slot.isAfter(DateTime.now())) {
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
          await (widget.sendInvite?.call(app.id, slot, setId, revision) ??
              InterviewService.schedule(
                applicationId: app.id,
                scheduledAt: slot,
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
        _selectedSlot = null;
        _message.clear();
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

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${_days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _zone {
    final offset = DateTime.now().timeZoneOffset;
    final minutes = offset.inMinutes.abs();
    return '${DateTime.now().timeZoneName} · UTC${offset.isNegative ? '-' : '+'}'
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: _dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (compact)
              _mobileHeader()
            else
              RecruiterTopBar(
                pageTitle: 'Schedule interview',
                mobileTitle: 'Schedule interview',
                dark: _dark,
                breadcrumbSegments: const ['Recruitment', 'Interviews'],
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _workspace(compact),
            ),
          ],
        ),
      ),
      bottomNavigationBar: compact
          ? const RecruiterMobileNav(
              currentRoute: '/recruiter/schedule-interview',
              key: Key('schedule-mobile-dock'),
            )
          : null,
    );
  }

  Widget _mobileHeader() => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: _surface,
      border: Border(bottom: BorderSide(color: _edge)),
    ),
    child: Row(
      children: [
        SvgPicture.asset('assets/images/logo.svg', width: 24, height: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Schedule interview',
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _edge),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'STEP 1–3',
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _workspace(bool compact) {
    final typography = Theme.of(context).textTheme.apply(fontFamily: 'Inter');
    final bodyStyle = (typography.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.52,
      color: _ink,
    );
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(textTheme: typography.copyWith(bodyMedium: bodyStyle)),
      child: DefaultTextStyle(
        style: bodyStyle,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            compact ? 16 : 24,
            compact ? 16 : 28,
            0,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= 720;
              final narrowForm = !split || constraints.maxWidth < 950;
              final form = _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _candidatePanel(),
                    Divider(height: 36, color: _edge),
                    _availabilityPanel(narrowForm),
                  ],
                ),
              );
              final review = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _questionReview(),
                  if (_interview != null) ...[
                    const SizedBox(height: 16),
                    _questionPanel(),
                  ],
                ],
              );
              return SingleChildScrollView(
                key: const Key('schedule-scroll'),
                primary: false,
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: 18),
                    if (_error case final error?) ...[
                      _panel(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                error,
                                style: TextStyle(color: _colors.error),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadJobs,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (split)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: form),
                          const SizedBox(width: 20),
                          Expanded(child: _invitationPanel()),
                        ],
                      )
                    else ...[
                      form,
                      const SizedBox(height: 16),
                      _invitationPanel(),
                    ],
                    const SizedBox(height: 16),
                    review,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pageHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Schedule an interview',
          style: TextStyle(
            color: _ink,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -.65,
          ),
        ),
      ),
      const SizedBox(height: 7),
      _body('Choose a shortlisted candidate and reserve an interview time.'),
      const SizedBox(height: 14),
      Divider(height: 1, color: _edge),
    ],
  );

  Widget _candidatePanel() => Column(
    key: const Key('schedule-candidate-card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading('01', 'Candidate & role'),
      const SizedBox(height: 6),
      _body('Only shortlisted candidates are available for scheduling.'),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final job = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Job opening'),
              const SizedBox(height: 8),
              _dropdown(
                key: const Key('schedule-job-dropdown'),
                value: _jobId,
                hint: 'Select a job opening',
                items: [
                  for (final job in _jobs)
                    (
                      id: job.id,
                      title: job.title,
                      subtitle: job.id == _jobId && _booked != null
                          ? _shortlistLabel
                          : job.department.trim(),
                    ),
                ],
                onChanged: _busyApplicationId == null ? _changeJob : null,
              ),
            ],
          );
          final candidate = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Candidate'),
              const SizedBox(height: 8),
              _dropdown(
                key: const Key('schedule-candidate-dropdown'),
                value: _selectedApplication?.id,
                hint: _jobId == null
                    ? 'Select a job first'
                    : 'Select a shortlisted candidate',
                items: [
                  for (final app in _awaiting)
                    (
                      id: app.id,
                      title: _candidateName(app),
                      subtitle: app.resumeScore == null
                          ? app.candidateEmail
                          : '${_scoreText(app.resumeScore!)}% match',
                    ),
                ],
                onChanged: _busyApplicationId != null
                    ? null
                    : (id) {
                        final app = _awaiting
                            .where((app) => app.id == id)
                            .firstOrNull;
                        if (app != null) _selectForReview(app);
                      },
              ),
            ],
          );
          return constraints.maxWidth >= 460
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: job),
                    const SizedBox(width: 16),
                    Expanded(child: candidate),
                  ],
                )
              : Column(children: [job, const SizedBox(height: 16), candidate]);
        },
      ),
      if (_jobId != null && _awaiting.isEmpty) ...[
        const SizedBox(height: 12),
        _body(
          _jobs.isEmpty
              ? 'Create an active role to begin scheduling.'
              : 'No eligible shortlisted candidates for this role.',
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed('/recruiter/pipeline'),
          child: const Text('Go to pipeline'),
        ),
      ],
    ],
  );

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
          : const Color(0xFF2563EB);
      final activeFill = _dark
          ? _colors.primaryContainer
          : const Color(0xFFF0F4FF);
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
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: BorderSide(color: open ? focusColor : _edge),
                  foregroundColor: selected == null ? _muted : _ink,
                  backgroundColor: _surface,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
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

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: _surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _edge),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _edge),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _blue, width: 1.5),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _edge),
    ),
  );

  Widget _availabilityPanel(bool compact) => Column(
    key: const Key('schedule-availability-card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading('02', 'Date & time'),
      const SizedBox(height: 7),
      _body(_zone),
      const SizedBox(height: 16),
      Row(
        children: [
          for (var day = 0; day < _days.length; day++) ...[
            if (day > 0) const SizedBox(width: 6),
            Expanded(child: _dayCard(day, compact)),
          ],
        ],
      ),
      const SizedBox(height: 16),
      _label('Available times'),
      const SizedBox(height: 9),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = compact ? 3 : 4;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in _slots)
                SizedBox(
                  width: width,
                  child: _slotChip(_slotFor(_selectedDay, time)),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      _body(
        'Booked and past times remain visible but cannot be selected.',
        size: 10,
      ),
    ],
  );

  Widget _dayCard(int day, bool compact) {
    final date = _dateFor(day), selected = day == _selectedDay;
    final available =
        date.weekday <= DateTime.friday &&
        _slotFor(day, _slots.last).isAfter(DateTime.now());
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('schedule-day-$day'),
        onTap: _busyApplicationId == null && available
            ? () => setState(() {
                _selectedDay = day;
                _selectedSlot = null;
              })
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: compact ? 66 : 82,
          decoration: BoxDecoration(
            color: selected ? _activeFill : _surface,
            border: Border.all(
              color: selected ? _blue : _edge,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _days[day].toUpperCase(),
                style: GoogleFonts.inter(
                  color: available ? _muted : _muted.withValues(alpha: .6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${date.day}',
                style: GoogleFonts.inter(
                  color: selected
                      ? _colors.onPrimaryContainer
                      : available
                      ? _ink
                      : _muted.withValues(alpha: .6),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(
                  _booked == null ? '—' : '${_bookedCount(day)} booked',
                  style: GoogleFonts.inter(color: _muted, fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotChip(DateTime slot) {
    final taken =
        _booked == null || _taken(slot) || !slot.isAfter(DateTime.now());
    final selected = _selectedSlot != null && _sameMinute(_selectedSlot!, slot);
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        key: ValueKey('schedule-slot-${_time(slot)}'),
        onPressed: taken || _busyApplicationId != null
            ? null
            : () => setState(() {
                _selectedSlot = slot;
                _rowErrors.clear();
              }),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: selected ? _colors.onPrimaryContainer : _ink,
          disabledForegroundColor: _muted.withValues(alpha: 0.45),
          backgroundColor: selected ? _activeFill : _surface,
          side: BorderSide(
            color: selected ? _blue : _edge,
            width: selected ? 1.5 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(
          _time(slot),
          style: GoogleFonts.inter(
            fontSize: 13,
            decoration: taken ? TextDecoration.lineThrough : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _edge)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: _muted, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _invitationPanel() => _panel(
    key: const Key('schedule-invitation-card'),
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading('Invitation details'),
              const SizedBox(height: 7),
              _body('Review the details before sending.'),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: _edge),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: _body('DRAFT', size: 10),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: _edge),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            children: [
              _summaryRow(
                'Candidate',
                _selectedApplication == null
                    ? 'Not selected'
                    : _candidateName(_selectedApplication!),
              ),
              _summaryRow(
                'Role',
                _jobs.where((job) => job.id == _jobId).firstOrNull?.title ??
                    'Select a role',
              ),
              _summaryRow('Date', _dateLabel(_dateFor(_selectedDay))),
              _summaryRow(
                'Time',
                _selectedSlot == null
                    ? 'Select a time'
                    : '${_time(_selectedSlot!)} ${DateTime.now().timeZoneName}',
              ),
              _summaryRow('Duration', 'Determined by interview agent'),
              _summaryRow('Format', 'AI-guided voice interview'),
            ],
          ),
        ),
        Divider(height: 1, color: _edge),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Send invitation via'),
              _deliveryOption(
                'In-app invitation',
                _inAppInvitation,
                (value) => setState(() => _inAppInvitation = value),
              ),
              _deliveryOption(
                'Email invitation',
                _emailInvitation,
                (value) => setState(() => _emailInvitation = value),
              ),
              const SizedBox(height: 5),
              _body(
                'Delivery preferences are a draft. The server manages actual delivery.',
                size: 12,
              ),
              const SizedBox(height: 18),
              _label('Optional message to candidate'),
              const SizedBox(height: 8),
              TextField(
                controller: _message,
                minLines: 3,
                maxLines: 5,
                style: GoogleFonts.inter(color: _ink, fontSize: 12),
                decoration: _inputDecoration().copyWith(
                  hintText: 'We look forward to speaking with you.',
                  hintStyle: TextStyle(color: _muted),
                ),
              ),
              const SizedBox(height: 6),
              _body(
                'Preview draft only. Invitations currently use the standard message.',
                size: 10,
              ),
              const SizedBox(height: 10),
              if (_applicationId != null &&
                  _rowErrors[_applicationId] != null) ...[
                const SizedBox(height: 12),
                Text(
                  _rowErrors[_applicationId]!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _sendButton(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _deliveryOption(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    dense: true,
    value: selected,
    onChanged: _busyApplicationId == null
        ? (value) => onChanged(value ?? false)
        : null,
    activeColor: const Color(0xFF087B67),
    checkColor: Colors.white,
    side: BorderSide(color: _colors.outline),
    checkboxShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(3),
    ),
    title: Text(label, style: TextStyle(color: _ink, fontSize: 14)),
  );

  Widget _sectionHeading(String number, String title) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _dark ? _colors.primaryContainer : const Color(0xFFEEF2F9),
          border: Border.all(color: _edge),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          number,
          style: TextStyle(
            color: _dark ? _colors.onPrimaryContainer : const Color(0xFF49658E),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: _heading(title)),
    ],
  );

  Widget _sendButton() => FilledButton(
    key: const Key('schedule-review-send'),
    onPressed:
        !_loading &&
            _error == null &&
            _selectedApplication != null &&
            _selectedSlot != null &&
            _booked != null &&
            !_taken(_selectedSlot!) &&
            _selectedSlot!.isAfter(DateTime.now()) &&
            _busyApplicationId == null
        ? _reviewAndSend
        : null,
    style: RecruiterButtonStyle.primary(
      FilledButton.styleFrom(
        backgroundColor: _blue,
        disabledBackgroundColor: _colors.surfaceContainerHighest,
        disabledForegroundColor: _muted,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    child: _busyApplicationId != null
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            'Send invitation',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
  );

  Widget _questionReview() => KeyedSubtree(
    key: _reviewKey,
    child: _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _selectedApplication == null
                ? null
                : () => setState(() => _reviewExpanded = !_reviewExpanded),
            child: Row(
              children: [
                Expanded(child: _heading('Review interview questions')),
                Icon(
                  _reviewExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          _body(
            _selectedApplication == null
                ? 'Select a candidate to review their interview questions.'
                : _canSchedule(_selectedApplication!)
                ? 'Current question revision approved.'
                : 'Question approval is required before sending.',
          ),
          if (_reviewExpanded && _selectedApplication != null) ...[
            const SizedBox(height: 12),
            QuestionPreparationPanel(
              key: ValueKey('$_applicationId-$_questionReload'),
              application: _selectedApplication,
              applicationId: _applicationId!,
              client: widget.questionClient,
              onApprovalChanged: (setId, revision) {
                setState(() {
                  _approvedQuestionApplication = setId == null
                      ? null
                      : _applicationId;
                  _approvedQuestionSet = setId;
                  _approvedQuestionRevision = revision;
                  if (setId != null) {
                    _scheduleReviewRequired.remove(_applicationId);
                  }
                });
              },
            ),
          ],
        ],
      ),
    ),
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
                _summaryRow('Date', _dateLabel(slot)),
                _summaryRow(
                  'Time',
                  '${_time(slot)} ${DateTime.now().timeZoneName}',
                ),
                _summaryRow('Interview type', 'Retell AI · Voice'),
                if (_message.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _label('Message draft (preview only)'),
                  const SizedBox(height: 8),
                  _body(_message.text.trim()),
                ],
                const SizedBox(height: 16),
                _body(
                  'Confirm to schedule this interview using the approved question revision and send the standard invitation.',
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
      _message.clear();
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
            if (mounted) _refreshQuestions();
          },
          child: const Text(
            'Review evidence, reschedule or schedule another attempt',
          ),
        ),
        Text(
          'Workflow: ${_interview!.workflowState} · ${_interview!.scheduledAt?.toLocal()} ${DateTime.now().timeZoneName}',
        ),
        Text('Preparation: ${_interview!.questionPreparationMode}'),
        if (_interview!.questionFallbackReason.isNotEmpty)
          Text('Reason: ${_interview!.questionFallbackReason}'),
        const SizedBox(height: 7),
        Text(
          'Interview ID: ${_interview!.id}',
          style: GoogleFonts.jetBrainsMono(color: _muted, fontSize: 10),
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

  Widget _panel({
    Key? key,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    required Widget child,
  }) => Container(
    key: key,
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _edge),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _dark ? 0.10 : 0.025),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _heading(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: _ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: _muted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
  Widget _body(String text, {double size = 14}) => Text(
    text,
    style: GoogleFonts.inter(
      color: _muted,
      fontSize: size,
      height: 1.52,
      fontWeight: FontWeight.w500,
    ),
  );
}
