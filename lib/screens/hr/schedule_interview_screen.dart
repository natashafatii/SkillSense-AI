import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/job.dart';
import '../../services/api_exception.dart';
import '../../services/application_service.dart';
import '../../services/auth_service.dart';
import '../../services/interview_service.dart';
import '../../services/job_service.dart';

/// Recruiter scheduling console for shortlisted applications.
class ScheduleInterviewScreen extends StatefulWidget {
  final String? jobId;
  final String? applicationId;
  final Future<List<Job>> Function()? loadJobs;
  final Future<List<Application>> Function(String jobId)? loadForJob;
  final Future<Application> Function(String applicationId)? loadApplication;
  final Future<List<Interview>> Function(String jobId)? loadBooked;
  final Future<Interview> Function(String applicationId, DateTime scheduledAt)?
  sendInvite;

  const ScheduleInterviewScreen({
    super.key,
    this.jobId,
    this.applicationId,
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
  static const _ink = Color(0xFF17233B);
  static const _muted = Color(0xFF8190A8);
  static const _edge = Color(0xFFE4EAF3);
  static const _blue = Color(0xFF4268F0);
  static const _slots = <(int, int)>[
    (9, 0),
    (10, 30),
    (11, 30),
    (13, 0),
    (14, 0),
    (15, 30),
    (17, 0),
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

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
  late DateTime _monday;
  late int _selectedDay;
  DateTime? _selectedSlot;

  Interview? _interview;
  List<InterviewQuestion> _questions = [];
  final Map<String, TextEditingController> _questionTexts = {};
  bool _questionsWorking = false;
  String? _questionError;
  String? _questionNotice;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    _applicationId = widget.applicationId;
    _monday = _weekStart(DateTime.now());
    _selectedDay = _initialDay();
    _loadJobs();
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
      final jobs = List<Job>.from(
        await (widget.loadJobs?.call() ?? JobService.listAllJobs()),
      );
      if (!mounted || request != _request) return;
      final requested = _jobId;
      if (requested != null && !jobs.any((job) => job.id == requested)) {
        jobs.add(await JobService.getJob(requested));
        if (!mounted || request != _request) return;
      }
      setState(() {
        _jobs = jobs;
        _jobId ??= jobs.isEmpty ? null : jobs.first.id;
      });
      await _loadAwaiting();
    } catch (error) {
      if (!mounted || request != _request) return;
      if (await _handleUnauthorized(error)) return;
      setState(() {
        _loading = false;
        _error = 'Could not load roles: $error';
      });
    }
  }

  Future<void> _loadAwaiting() async {
    final request = ++_request;
    final jobId = _jobId;
    if (jobId == null || jobId.isEmpty) {
      setState(() {
        _awaiting = [];
        _booked = null;
        _loading = false;
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
      final applications =
          await (widget.loadForJob?.call(jobId) ??
              ApplicationService.listAllForJob(jobId, status: 'SHORTLISTED'));
      if (!mounted || request != _request || jobId != _jobId) return;
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
        if (!shortlisted.any((app) => app.id == _applicationId)) {
          _applicationId = null;
        }
        _loading = false;
      });
      _loadBookings(jobId, request);
    } catch (error) {
      if (!mounted || request != _request || jobId != _jobId) return;
      if (await _handleUnauthorized(error)) return;
      setState(() {
        _error = 'Could not load shortlisted applications: $error';
        _loading = false;
      });
    }
  }

  bool _isShortlisted(Application app) =>
      (app.rawStatus ?? app.status.value).toUpperCase() == 'SHORTLISTED';

  Future<void> _loadBookings(String jobId, int request) async {
    try {
      final booked =
          await (widget.loadBooked?.call(jobId) ??
              InterviewService.listForJob(jobId));
      if (!mounted || request != _request || jobId != _jobId) return;
      setState(() => _booked = booked);
    } catch (error) {
      if (!mounted || request != _request || jobId != _jobId) return;
      await _handleUnauthorized(error);
      // Some backends do not expose a readable interview list. Unknown
      // availability is shown as a dash rather than an invented count.
    }
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
      _selectedSlot = null;
      _rowErrors.clear();
      _interview = null;
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

  String _slotLabel(DateTime date) =>
      '${_time(date)} ${_days[date.weekday - 1]}';

  Future<void> _sendInvite(Application app) async {
    final slot = _selectedSlot;
    if (slot == null || !slot.isAfter(DateTime.now())) {
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
          await (widget.sendInvite?.call(app.id, slot) ??
              InterviewService.schedule(
                applicationId: app.id,
                scheduledAt: slot,
              ));
      if (!mounted || app.job != _jobId) return;
      setState(() {
        _interview = interview;
        _scheduledIds.add(app.id);
        _awaiting.removeWhere((item) => item.id == app.id);
        _booked = [...?_booked, interview];
        _applicationId = null;
        _selectedSlot = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview invitation scheduled.')),
      );
      await _loadAwaiting();
    } catch (error) {
      if (!mounted) return;
      if (await _handleUnauthorized(error)) return;
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
            ? 'Generated questions are pending.'
            : 'Review the generated questions before approval.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _questionError = 'Could not load questions: $error');
      }
    } finally {
      if (mounted) setState(() => _questionsWorking = false);
    }
  }

  Future<void> _saveQuestions({required bool approve}) async {
    final id = _interview?.id;
    if (id == null || _questions.isEmpty) return;
    final edited = _questions
        .map(
          (question) => InterviewQuestion(
            id: question.id,
            text: _questionTexts[question.id]!.text.trim(),
            isApproved: approve || question.isApproved,
          ),
        )
        .toList();
    if (edited.any((question) => question.text.isEmpty)) {
      setState(() => _questionError = 'Question text cannot be empty.');
      return;
    }
    setState(() {
      _questionsWorking = true;
      _questionError = null;
    });
    try {
      final confirmed = await InterviewService.saveQuestions(id, edited);
      if (!mounted || _interview?.id != id) return;
      setState(() {
        _questions = confirmed;
        _questionNotice = approve
            ? 'Questions approved by the server.'
            : 'Question edits saved by the server.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _questionError = 'Question update failed: $error');
      }
    } finally {
      if (mounted) setState(() => _questionsWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(compact),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_jobs.length > 1) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DropdownButton<String>(
                              value: _jobId,
                              items: [
                                for (final job in _jobs)
                                  DropdownMenuItem(
                                    value: job.id,
                                    child: Text(job.title),
                                  ),
                              ],
                              onChanged: _busyApplicationId == null
                                  ? _changeJob
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_loading)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFDC354A)),
                          ),
                          TextButton(
                            onPressed: _loadJobs,
                            child: const Text('Retry'),
                          ),
                        ],
                        if (!_loading && _jobs.isEmpty)
                          _panel(
                            child: const Text('No recruiter jobs available.'),
                          )
                        else if (compact)
                          Column(
                            children: [
                              _weekPanel(),
                              const SizedBox(height: 14),
                              _awaitingPanel(),
                              const SizedBox(height: 14),
                              _invitationPanel(),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 14,
                                child: Column(
                                  children: [
                                    _weekPanel(),
                                    const SizedBox(height: 14),
                                    _invitationPanel(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(flex: 10, child: _awaitingPanel()),
                            ],
                          ),
                        if (_interview != null) ...[
                          const SizedBox(height: 14),
                          _questionPanel(),
                        ],
                      ],
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

  Widget _topBar(bool compact) => Container(
    height: 55,
    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: _edge)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'SCHEDULE INTERVIEW',
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        if (!compact) ...[
          Container(
            width: 260,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: _edge),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 15, color: _muted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Search or jump to...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: _muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        const Icon(Icons.notifications_none_rounded, size: 19, color: _muted),
        const SizedBox(width: 13),
        const Icon(Icons.help_outline_rounded, size: 19, color: _muted),
      ],
    ),
  );

  Widget _weekPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _heading('This week')),
            Text(
              '${_monday.month}/${_monday.day}–${_dateFor(4).month}/${_dateFor(4).day}',
              style: GoogleFonts.inter(color: _muted, fontSize: 10),
            ),
          ],
        ),
        const Divider(height: 26, color: _edge),
        Row(
          children: [
            for (var day = 0; day < 5; day++) ...[
              if (day > 0) const SizedBox(width: 7),
              Expanded(child: _dayCard(day)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _tick('${_days[_selectedDay].toUpperCase()} SLOTS · AGENT CAPACITY'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final time in _slots) _slotChip(_slotFor(_selectedDay, time)),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: _edge),
        const SizedBox(height: 11),
        _tick('AGENT CONFIG'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _configChip('Retell · voice EN-F2'),
            _configChip('8 questions'),
            _configChip('Proctoring on'),
            _configChip('Recording on'),
          ],
        ),
      ],
    ),
  );

  Widget _dayCard(int day) {
    final date = _dateFor(day);
    final selected = day == _selectedDay;
    return InkWell(
      onTap: _busyApplicationId == null
          ? () => setState(() {
              _selectedDay = day;
              _selectedSlot = null;
            })
          : null,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5ECFF) : const Color(0xFFFCFDFF),
          border: Border.all(color: selected ? const Color(0xFFBCD0FF) : _edge),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tick(_days[day].toUpperCase()),
            Text(
              '${date.day}',
              style: GoogleFonts.jetBrainsMono(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _booked == null ? '—' : '${_bookedCount(day)} booked',
              style: GoogleFonts.inter(color: _muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotChip(DateTime slot) {
    final taken = _taken(slot) || !slot.isAfter(DateTime.now());
    final selected = _selectedSlot != null && _sameMinute(_selectedSlot!, slot);
    return ChoiceChip(
      label: Text(
        _time(slot),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: taken
              ? const Color(0xFFADB8C9)
              : selected
              ? _blue
              : _muted,
          decoration: taken ? TextDecoration.lineThrough : null,
        ),
      ),
      selected: selected,
      onSelected: taken || _busyApplicationId != null
          ? null
          : (_) => setState(() {
              _selectedSlot = slot;
              _rowErrors.clear();
            }),
      selectedColor: const Color(0xFFE4ECFF),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? const Color(0xFFBCD0FF) : _edge),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _awaitingPanel() => _panel(
    padding: EdgeInsets.zero,
    hot: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Awaiting schedule',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              _configChip('SHORTLIST · ${_awaiting.length}', active: true),
            ],
          ),
        ),
        const Divider(height: 1, color: _edge),
        if (!_loading && _awaiting.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Text(
                'No shortlisted candidates yet',
                style: GoogleFonts.inter(color: _muted, fontSize: 11),
              ),
            ),
          ),
        for (var index = 0; index < _awaiting.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: _edge),
          _candidateRow(_awaiting[index]),
        ],
      ],
    ),
  );

  Widget _candidateRow(Application app) {
    final selected = _applicationId == app.id;
    final busy = _busyApplicationId == app.id;
    final name = _candidateName(app);
    final date = app.updatedAt ?? app.createdAt;
    final error = _rowErrors[app.id];
    return InkWell(
      onTap: _busyApplicationId == null
          ? () => setState(() => _applicationId = app.id)
          : null,
      child: Container(
        color: selected ? const Color(0xFFF7F9FF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5ECFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _initials(name),
                    style: GoogleFonts.inter(
                      color: _blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Shortlisted ${_timeAgo(date)}${app.resumeScore == null ? '' : ' · ${_scoreText(app.resumeScore!)}'}',
                        style: GoogleFonts.inter(color: _muted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _selectedSlot != null && _busyApplicationId == null
                      ? () => _sendInvite(app)
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(75, 31),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    backgroundColor: _blue,
                    textStyle: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedSlot == null
                              ? 'Pick slot'
                              : _slotLabel(_selectedSlot!),
                        ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 7),
              Text(
                error,
                style: GoogleFonts.inter(
                  color: const Color(0xFFD64255),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
    final delta = DateTime.now().difference(date);
    if (delta.isNegative || delta.inMinutes < 1) return 'just now';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  String _scoreText(double score) => score == score.roundToDouble()
      ? score.round().toString()
      : score.toStringAsFixed(1);

  Widget _invitationPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Invitation'),
        const Divider(height: 25, color: _edge),
        Text(
          'Candidate receives email + in-app invite with device-check link. '
          'Auto-reminder 24h and 1h before.',
          style: GoogleFonts.inter(color: _muted, fontSize: 10, height: 1.6),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _applicationId != null && _selectedSlot != null
                    ? () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Invitation preview'),
                          content: Text(
                            'Interview invitation for ${_candidateName(_awaiting.firstWhere((app) => app.id == _applicationId))} on '
                            '${_selectedSlot!.toLocal()}.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      )
                    : null,
                child: const Text('Preview email'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton(
                onPressed:
                    _applicationId != null &&
                        _selectedSlot != null &&
                        _busyApplicationId == null
                    ? () => _sendInvite(
                        _awaiting.firstWhere((app) => app.id == _applicationId),
                      )
                    : null,
                style: FilledButton.styleFrom(backgroundColor: _blue),
                child: _busyApplicationId != null
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send invite'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _questionPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Generated questions'),
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
          child: const Text('Refresh generated questions'),
        ),
        for (final question in _questions)
          TextField(
            controller: _questionTexts[question.id],
            maxLines: 2,
            decoration: InputDecoration(
              labelText:
                  'Question ${question.id}${question.isApproved ? ' · approved' : ' · pending approval'}',
            ),
          ),
        if (_questions.isNotEmpty)
          Row(
            children: [
              TextButton(
                onPressed: _questionsWorking
                    ? null
                    : () => _saveQuestions(approve: false),
                child: const Text('Save edits'),
              ),
              FilledButton(
                onPressed: _questionsWorking
                    ? null
                    : () => _saveQuestions(approve: true),
                child: const Text('Approve questions'),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    bool hot = false,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _edge),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF596B96).withValues(alpha: hot ? 0.12 : 0.06),
          blurRadius: hot ? 26 : 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: hot
        ? ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF20D9BD),
                        Color(0xFF627AFF),
                        Color(0xFFE0E7FF),
                      ],
                    ),
                  ),
                ),
                child,
              ],
            ),
          )
        : child,
  );

  Widget _heading(String label) => Text(
    label,
    style: GoogleFonts.inter(
      color: _ink,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _tick(String label) => Text(
    label,
    style: GoogleFonts.spaceGrotesk(
      color: _muted,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  Widget _configChip(String label, {bool active = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE6EDFF) : Colors.white,
      border: Border.all(color: active ? const Color(0xFFCAD8FF) : _edge),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(color: active ? _blue : _muted, fontSize: 9),
    ),
  );
}
