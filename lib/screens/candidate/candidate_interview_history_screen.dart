import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/application.dart';
import '../../models/candidate_feedback.dart';
import '../../models/interview.dart';
import '../../services/application_service.dart';
import '../../services/feedback_service.dart';
import '../../services/interview_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../application_screening_screen.dart';

class CandidateInterviewHistoryScreen extends StatefulWidget {
  const CandidateInterviewHistoryScreen({
    super.key,
    this.loadInterviews,
    this.loadApplications,
    this.loadFeedback,
  });

  final Future<List<Interview>> Function()? loadInterviews;
  final Future<List<Application>> Function()? loadApplications;
  final Future<List<CandidateFeedback>> Function()? loadFeedback;

  @override
  State<CandidateInterviewHistoryScreen> createState() =>
      _CandidateInterviewHistoryScreenState();
}

enum _Filter {
  all('All'),
  released('Feedback released'),
  selected('Selected'),
  rejected('Not selected'),
  interrupted('Interrupted');

  const _Filter(this.label);
  final String label;

  bool matches(_HistoryEntry entry) => switch (this) {
    all => true,
    released => entry.report != null,
    selected => entry.selected,
    rejected => entry.rejected,
    interrupted => entry.interrupted,
  };
}

enum _Sort {
  newest('Newest first'),
  score('Highest score');

  const _Sort(this.label);
  final String label;
}

class _HistoryEntry {
  const _HistoryEntry(this.interview, this.application, this.report);
  final Interview interview;
  final Application? application;
  final CandidateFeedbackReport? report;

  DateTime? get date =>
      (interview.scheduledAt ?? interview.completedAt)?.toLocal();
  DateTime? get sortDate => interview.completedAt ?? interview.scheduledAt;
  double? get score => report?.performance;
  bool? get videoRequired => switch (interview) {
    CandidateInterview(:final videoRequired) => videoRequired,
    _ => null,
  };
  String? get format => switch (videoRequired) {
    true => 'AI-guided video interview',
    false => 'AI-guided voice interview',
    null => null,
  };
  String get title => application?.jobTitle.trim().isNotEmpty == true
      ? application!.jobTitle
      : 'Interview';
  String get company => application?.jobCompany.trim() ?? '';
  String? get _outcome => application?.outcome?.trim().toUpperCase();
  bool get selected =>
      application?.rawStatus?.trim().toUpperCase() == 'HIRED' ||
      const {'HIRE', 'HIRED'}.contains(_outcome);
  bool get rejected =>
      application?.status == ApplicationStatus.rejected ||
      const {
        'REJECT',
        'REJECTED',
        'NO',
        'NOT_SELECTED',
        'NOT SELECTED',
      }.contains(_outcome);
  bool get interrupted =>
      interview.workflowState == 'INTERRUPTED' ||
      interview.status == 'INTERRUPTED';
}

class _CandidateInterviewHistoryScreenState
    extends State<CandidateInterviewHistoryScreen> {
  List<_HistoryEntry> _items = [];
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.newest;
  String? _expanded, _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(_clear);
    _load();
  }

  void _clear() {
    ++_request;
    setState(() {
      _items = [];
      _expanded = null;
      _loading = false;
      _error = 'Session changed. Sign in again.';
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    final generation = SessionScope.generation;
    bool current() =>
        mounted && request == _request && generation == SessionScope.generation;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });
    try {
      final (interviews, applications, feedback) = await (
        widget.loadInterviews?.call() ?? InterviewService.listAll(),
        widget.loadApplications?.call() ??
            ApplicationService.listAllApplications(),
        widget.loadFeedback?.call() ??
            FeedbackService.forIdentity().then((page) => page.results),
      ).wait;
      if (!current()) return;
      final byApplication = {for (final app in applications) app.id: app};
      final reports = {
        for (final row in feedback)
          if (row.report != null)
            (row.interviewId, row.applicationId): row.report!,
      };
      final entries = [
        for (final interview in interviews)
          if (interview.status == 'DONE' ||
              interview.status == 'INTERRUPTED' ||
              interview.workflowState == 'INTERRUPTED')
            _HistoryEntry(
              interview,
              byApplication[interview.applicationId],
              reports[(interview.id, interview.applicationId)],
            ),
      ]..sort(_newest);
      setState(() {
        _items = entries;
        _expanded = entries.firstOrNull?.interview.id;
      });
    } catch (_) {
      if (current()) {
        setState(() => _error = 'Unable to load interview history. Try again.');
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    ++_request;
    SessionScope.invalidations.removeListener(_clear);
    super.dispose();
  }

  static int _newest(_HistoryEntry a, _HistoryEntry b) =>
      (b.sortDate?.millisecondsSinceEpoch ?? 0).compareTo(
        a.sortDate?.millisecondsSinceEpoch ?? 0,
      );

  Color get _blue => _dark ? const Color(0xFF83A9FF) : const Color(0xFF285FD0);
  Color get _green => _dark ? const Color(0xFF6EE7BD) : const Color(0xFF087C57);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _ink => _dark ? _colors.onSurface : const Color(0xFF1D2740);
  Color get _mute => _dark ? _colors.onSurfaceVariant : const Color(0xFF596982);
  Color get _edge => _dark ? _colors.outlineVariant : const Color(0xFFE6E9EF);
  Color get _surface => _dark ? _colors.surface : Colors.white;
  Color get _soft =>
      _dark ? _colors.surfaceContainerHigh : const Color(0xFFF2F5FA);

  @override
  Widget build(BuildContext context) => CandidateScaffold(
    currentRoute: '/candidate/interviews',
    body: Column(
      children: [
        const RecruiterTopBar(pageTitle: 'Interview history', candidate: true),
        Expanded(
          child: ColoredBox(
            color: _dark
                ? Theme.of(context).scaffoldBackgroundColor
                : const Color(0xFFF8F9FB),
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(
                  context,
                ).textTheme.apply(fontFamily: 'Inter'),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: _ink,
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 56),
                        children: [
                          _header(),
                          const SizedBox(height: 20),
                          if (_error case final error?)
                            _empty(error)
                          else ...[
                            _summary(),
                            const SizedBox(height: 22),
                            _filters(),
                            const SizedBox(height: 14),
                            ..._rows(),
                          ],
                          if (MediaQuery.sizeOf(context).width < 900)
                            const SizedBox(height: 72),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _header() {
    final released = _items.where(_Filter.released.matches).length;
    final interrupted = _items.where(_Filter.interrupted.matches).length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interview history',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              if (_error == null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_items.length} ${_items.length == 1 ? 'interview' : 'interviews'} · $released with feedback${interrupted > 0 ? ' · $interrupted interrupted' : ''}',
                  style: TextStyle(color: _mute, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh interview history',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _summary() {
    final reports = _items.where((entry) => entry.report != null).toList()
      ..sort((a, b) => a.report!.releasedAt.compareTo(b.report!.releasedAt));
    final scored = reports.where((entry) => entry.score != null).toList();
    final best = scored.isEmpty
        ? null
        : scored.reduce((a, b) => a.score! > b.score! ? a : b);
    final cells = [
      _reportCell('Latest report', reports.lastOrNull),
      _reportCell('Best score', best),
      _trend(scored.map((entry) => entry.score!).toList()),
    ];
    return _card(
      radius: 20,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 660
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cells[0],
                  Divider(height: 1, color: _edge),
                  cells[1],
                  Divider(height: 1, color: _edge),
                  cells[2],
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cells[0]),
                    VerticalDivider(width: 1, color: _edge),
                    Expanded(child: cells[1]),
                    VerticalDivider(width: 1, color: _edge),
                    Expanded(flex: 2, child: cells[2]),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _reportCell(String label, _HistoryEntry? entry) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: Row(
      children: [
        _ring(entry?.score),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _eyebrow(label),
              const SizedBox(height: 3),
              Text(
                entry?.title ?? 'No report available',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry != null)
                Text(
                  [
                    if (entry.date case final date?)
                      MaterialLocalizations.of(context).formatShortDate(date),
                    if (entry.company.isNotEmpty) entry.company,
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: _mute),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _trend(List<double> values) {
    final delta = values.length > 1 ? values.last - values.first : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _eyebrow('Score trend'),
          const SizedBox(height: 4),
          Text(
            delta == null
                ? 'Available after two scored reports'
                : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} pts since first report',
            style: TextStyle(
              color: delta != null && delta >= 0 ? _green : _mute,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (delta != null)
            Semantics(
              label:
                  'Scores over time: ${values.map((value) => value.round()).join(', ')}',
              child: SizedBox(
                height: 46,
                width: double.infinity,
                child: CustomPaint(painter: _Sparkline(values, _blue, _green)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _Filter.values)
          ChoiceChip(
            label: Text(
              '${filter.label}  ${_items.where(filter.matches).length}',
            ),
            selected: _filter == filter,
            showCheckmark: false,
            backgroundColor: _surface,
            selectedColor: _green.withValues(alpha: .1),
            side: BorderSide(
              color: _filter == filter ? _green.withValues(alpha: .35) : _edge,
            ),
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _filter == filter ? _green : _mute,
            ),
            onSelected: (_) => setState(() => _filter = filter),
          ),
      ],
    );
    const sortWidth = 146.0;
    const selectionBlue = Color(0xFF1967D2);
    final sort = MenuAnchor(
      alignmentOffset: const Offset(0, 2),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(_surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(Size(sortWidth, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(side: BorderSide(color: _edge)),
        ),
      ),
      menuChildren: [
        for (final option in _Sort.values)
          Semantics(
            selected: option == _sort,
            child: MenuItemButton(
              style: MenuItemButton.styleFrom(
                minimumSize: const Size(sortWidth, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                foregroundColor: option == _sort ? Colors.white : _ink,
                backgroundColor: option == _sort ? selectionBlue : _surface,
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () => setState(() => _sort = option),
              child: Text(option.label),
            ),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Sort interviews',
        child: OutlinedButton(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style:
              OutlinedButton.styleFrom(
                minimumSize: const Size(sortWidth, 44),
                backgroundColor: _surface,
                foregroundColor: _mute,
                padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ).copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) =>
                      controller.isOpen || states.contains(WidgetState.focused)
                      ? BorderSide(color: _blue, width: 2)
                      : BorderSide(color: _edge),
                ),
              ),
          child: SizedBox(
            width: sortWidth - 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_sort.label),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 720
          ? Row(
              children: [
                Expanded(child: chips),
                const SizedBox(width: 12),
                sort,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                chips,
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: sort),
              ],
            ),
    );
  }

  Iterable<Widget> _rows() {
    final visible = _items.where(_filter.matches).toList();
    if (_sort == _Sort.score) {
      visible.sort((a, b) {
        final byScore = (b.score ?? -1).compareTo(a.score ?? -1);
        return byScore == 0 ? _newest(a, b) : byScore;
      });
    }
    if (visible.isEmpty) {
      return [
        _empty(
          _items.isEmpty
              ? 'No completed interviews yet.'
              : 'No interviews match this filter.',
        ),
      ];
    }
    return [
      for (final entry in visible)
        Padding(
          key: ValueKey(entry.interview.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: _entry(entry),
        ),
    ];
  }

  Widget _entry(_HistoryEntry entry) {
    final open = _expanded == entry.interview.id;
    final title = entry.company.isEmpty
        ? entry.title
        : '${entry.title} · ${entry.company}';
    final badges = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (entry.interrupted)
          _badge(
            'Interrupted',
            Icons.pause,
            _dark ? const Color(0xFFFFD08A) : const Color(0xFF8F5C12),
          ),
        if (entry.selected) _badge('Selected', Icons.check, _green),
        if (entry.rejected) _badge('Not selected', Icons.close, _colors.error),
        if (entry.report != null)
          _badge('Feedback released', Icons.description_outlined, _blue)
        else if (!entry.interrupted)
          _badge('Feedback not released', Icons.lock_outline, _mute),
      ],
    );
    return _card(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: open,
            button: true,
            child: InkWell(
              onTap: () =>
                  setState(() => _expanded = open ? null : entry.interview.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 670;
                    return Row(
                      children: [
                        _dateBox(entry.date),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                              if (entry.format case final format?)
                                Text(
                                  '$format · with SkillSense Interview Agent',
                                  style: TextStyle(color: _mute, fontSize: 13),
                                ),
                              if (!wide) ...[const SizedBox(height: 6), badges],
                            ],
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * .47,
                            ),
                            child: badges,
                          ),
                        ],
                        const SizedBox(width: 8),
                        _ring(entry.score),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: open ? .5 : 0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            color: _mute,
                            size: 19,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (open) _details(entry),
        ],
      ),
    );
  }

  Widget _details(_HistoryEntry entry) {
    final date = entry.date;
    final local = MaterialLocalizations.of(context);
    final guidance = entry.report?.publicSummary?.trim() ?? '';
    final note = guidance.isNotEmpty
        ? guidance
        : entry.report?.summary.trim() ?? '';
    final facts = [
      (
        'Date',
        date == null
            ? 'Not available'
            : '${local.formatShortMonthDay(date)} ${date.year}, ${TimeOfDay.fromDateTime(date).format(context)}',
      ),
      ('Format', entry.format ?? 'Not available'),
      (
        'Score',
        entry.score == null ? 'Not available' : '${entry.score!.round()} / 100',
      ),
      (
        'Application',
        entry.interview.applicationId.isEmpty
            ? 'Not available'
            : entry.interview.applicationId,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final notePanel = DecoratedBox(
            decoration: BoxDecoration(
              color: _dark ? _soft : const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eyebrow(
                    entry.interrupted && entry.report == null
                        ? 'What happened'
                        : guidance.isNotEmpty
                        ? 'Interviewer note'
                        : 'Feedback',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.isNotEmpty
                        ? note
                        : entry.report != null
                        ? 'No note was included in the released report.'
                        : entry.interrupted
                        ? 'The call was interrupted and no feedback has been released. An unavailable score does not count as zero.'
                        : 'Your recruiter hasn’t released feedback for this interview yet.',
                    style: TextStyle(color: _ink, fontSize: 14, height: 1.65),
                  ),
                ],
              ),
            ),
          );
          final factPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.format != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _blue.withValues(alpha: .12),
                      foregroundColor: _blue,
                      child: const Text(
                        'AI',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SkillSense Interview Agent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Automated interviewer',
                            style: TextStyle(fontSize: 12.5, color: _mute),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              for (var index = 0; index < facts.length; index += 2) ...[
                if (index > 0) const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _fact(facts[index])),
                    const SizedBox(width: 14),
                    Expanded(child: _fact(facts[index + 1])),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: entry.interrupted && entry.report == null
                        ? () => Navigator.pushNamed(
                            context,
                            '/candidate/interview-lobby',
                          )
                        : entry.report == null
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            '/candidate/feedback-report',
                            arguments: {
                              'interviewId': entry.interview.id,
                              'applicationId': entry.interview.applicationId,
                            },
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF285FD0),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(
                      entry.interrupted && entry.report == null
                          ? 'Go to interview lobby'
                          : 'View feedback',
                    ),
                  ),
                  if (entry.interview.applicationId.isNotEmpty)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _surface,
                        foregroundColor: _ink,
                        minimumSize: const Size(0, 44),
                        side: BorderSide(color: _edge),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ApplicationScreeningScreen(
                            applicationId: entry.interview.applicationId,
                          ),
                        ),
                      ),
                      child: const Text('Application details'),
                    ),
                ],
              ),
            ],
          );
          return constraints.maxWidth >= 740
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: 74),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: notePanel),
                        const SizedBox(width: 28),
                        Expanded(flex: 5, child: factPanel),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [notePanel, const SizedBox(height: 14), factPanel],
                );
        },
      ),
    );
  }

  Widget _fact((String, String) fact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _eyebrow(fact.$1),
      const SizedBox(height: 3),
      SelectableText(
        fact.$2,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    ],
  );

  Widget _dateBox(DateTime? date) {
    final month = date == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatShortMonthDay(date).replaceAll(RegExp(r'\d'), '').trim();
    return Container(
      width: 56,
      height: 60,
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date?.day.toString().padLeft(2, '0') ?? '–',
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 21,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          if (month != null) _eyebrow(month),
        ],
      ),
    );
  }

  Widget _ring(double? score) => Semantics(
    label: score == null
        ? 'No score available'
        : 'Score ${score.round()} out of 100',
    excludeSemantics: true,
    child: SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (score == null)
            CustomPaint(painter: _DashedScoreRing(_mute.withValues(alpha: .42)))
          else
            CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 4.5,
              backgroundColor: _edge,
              color: score >= 75 ? _green : _blue,
            ),
          Center(
            child: Text(
              score?.round().toString() ?? '–',
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _badge(String label, IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      border: Border.all(color: color.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(99),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _eyebrow(String label) => Text(
    label.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 1,
      fontWeight: FontWeight.w700,
      color: _mute,
    ),
  );

  Widget _empty(String message) => _card(
    radius: 18,
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: _mute),
      ),
    ),
  );

  Widget _card({required double radius, required Widget child}) => Material(
    color: _surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: _edge),
    ),
    child: child,
  );
}

class _DashedScoreRing extends CustomPainter {
  const _DashedScoreRing(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    const segments = 24;
    const step = 2 * math.pi / segments;
    for (var segment = 0; segment < segments; segment++) {
      canvas.drawArc(bounds, segment * step, step * .62, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedScoreRing oldDelegate) =>
      oldDelegate.color != color;
}

class _Sparkline extends CustomPainter {
  const _Sparkline(this.values, this.line, this.end);
  final List<double> values;
  final Color line, end;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 12 || size.height <= 12) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).clamp(1, 100);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          6 + i * (size.width - 12) / (values.length - 1),
          max == min
              ? size.height / 2
              : size.height - 6 - (values[i] - min) / span * (size.height - 12),
        ),
    ];
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..color = line
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        i == points.length - 1 ? 4 : 2.5,
        Paint()..color = i == points.length - 1 ? end : line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Sparkline oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.line != line ||
      oldDelegate.end != end;
}
