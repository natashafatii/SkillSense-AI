import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/recruitment_evidence.dart';
import '../../services/api_exception.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../services/session_scope.dart';
import '../../widgets/recruiter_mobile_nav.dart';
import '../../widgets/interview_review_top_bar.dart';
import '../../widgets/page_heading_style.dart';
import 'recruitment_review_screen.dart' show RecruitmentReviewScreen;

class InterviewReviewScreen extends StatefulWidget {
  const InterviewReviewScreen({super.key, this.service});
  final RecruitmentWorkflowService? service;
  @override
  State<InterviewReviewScreen> createState() => _InterviewReviewScreenState();
}

enum _InterviewFilter {
  all('All'),
  needsDecision('Needs decision'),
  decided('Decided');

  const _InterviewFilter(this.label);
  final String label;
}

class _InterviewReviewScreenState extends State<InterviewReviewScreen> {
  List<RecruiterInterview> interviews = const [];
  Map<String, (Application, RecruiterDecision?)> candidates = const {};
  Map<String, double> scores = const {};
  Set<String> latestAttempts = const {};
  _InterviewFilter filter = _InterviewFilter.all;
  String search = '';
  String? error;
  bool loading = true, notFound = false, started = false;
  final token = CancelToken();
  static const _ink = Color(0xFF16213A);
  static const _sub = Color(0xFF3D4A63);
  static const _muted = Color(0xFF5F6C85);
  static const _line = Color(0xFFE2E8F2);
  static const _separator = Color(0xFFEDF1F7);
  static const _gap = 14.0;
  static const _columns = [284, 134, 128, 188, 183, 83];

  @override
  void initState() {
    super.initState();
    SessionScope.invalidations.addListener(clear);
  }

  void clear() {
    token.cancel('Session changed.');
    if (mounted) {
      setState(() {
        interviews = [];
        candidates = const {};
        scores = const {};
        latestAttempts = const {};
        error = 'Session changed.';
        loading = false;
      });
    }
  }

  Future<void> load() async {
    if (notFound || token.isCancelled) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final service = widget.service ?? RecruitmentWorkflowService();
      final result = await service.interviews(cancelToken: token);
      // Interviews are returned newest first. The scoring endpoint publishes
      // the current application score for its latest attempt.
      final latest = <String, RecruiterInterview>{};
      for (final interview in result) {
        latest.putIfAbsent(interview.applicationId, () => interview);
      }
      final attempts = latest.values.toList();
      final details = <String, (Application, RecruiterDecision?)>{};
      final published = <String, double>{};
      for (var offset = 0; offset < attempts.length; offset += 6) {
        if (!mounted || token.isCancelled) return;
        await Future.wait(
          attempts.skip(offset).take(6).map((attempt) async {
            final id = attempt.applicationId;
            try {
              final data = await service.request(
                '/applications/$id/',
                cancelToken: token,
              );
              final decision = data['decision'];
              details[id] = (
                Application.fromJson(data),
                decision is Map<String, dynamic>
                    ? RecruiterDecision.fromJson(decision)
                    : null,
              );
            } on ApiException {
              // An unavailable application must not hide the other interviews.
            }
            if (token.isCancelled ||
                !details.containsKey(id) ||
                attempt.status != 'DONE' ||
                attempt.workflowState != 'EVALUATED') {
              return;
            }
            try {
              final data = await service.request(
                '/applications/$id/scoring/',
                cancelToken: token,
              );
              if (data['current'] case final Map<String, dynamic> current) {
                final score = ServerScore.fromJson(current).publishedCombined;
                if (score != null) published[attempt.id] = score;
              }
            } on ApiException {
              // The score cell remains unavailable if the request fails.
            }
          }),
        );
      }
      if (mounted && !token.isCancelled) {
        setState(() {
          interviews = result;
          candidates = details;
          scores = published;
          latestAttempts = attempts.map((attempt) => attempt.id).toSet();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && !token.isCancelled) {
        setState(() {
          error = '$e';
          if (e is ApiException && e.accessUnavailable) {
            interviews = [];
            candidates = const {};
            scores = const {};
            latestAttempts = const {};
          }
          loading = false;
          notFound = e is ApiException && e.statusCode == 404;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && ModalRoute.of(context)?.isCurrent == true) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void dispose() {
    SessionScope.invalidations.removeListener(clear);
    token.cancel();
    super.dispose();
  }

  bool _needsDecision(RecruiterInterview interview) {
    final candidate = candidates[interview.applicationId];
    return candidate != null &&
        latestAttempts.contains(interview.id) &&
        candidate.$2 == null &&
        !const {
          ApplicationStatus.decision,
          ApplicationStatus.rejected,
          ApplicationStatus.unknown,
        }.contains(candidate.$1.status) &&
        interview.status == 'DONE' &&
        interview.workflowState == 'EVALUATED' &&
        interview.completionOutcome == 'USABLE' &&
        interview.evaluationStatus == 'READY' &&
        interview.completedAt != null;
  }

  bool _decided(RecruiterInterview interview) {
    final outcome = candidates[interview.applicationId]?.$2?.outcome;
    return latestAttempts.contains(interview.id) &&
        (outcome == 'HIRE' || outcome == 'REJECT');
  }

  bool _matches(RecruiterInterview interview) {
    final application = candidates[interview.applicationId]?.$1;
    final query = search.trim().toLowerCase();
    final matchesSearch = [
      application?.candidateName,
      application?.candidateEmail,
      application?.jobTitle,
      interview.id,
    ].whereType<String>().any((value) => value.toLowerCase().contains(query));
    return matchesSearch &&
        switch (filter) {
          _InterviewFilter.all => true,
          _InterviewFilter.needsDecision => _needsDecision(interview),
          _InterviewFilter.decided => _decided(interview),
        };
  }

  Future<void> _open(RecruiterInterview interview) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecruitmentReviewScreen(
          applicationId: interview.applicationId,
          interviewId: interview.id,
          service: widget.service,
          showInterviewDashboard: true,
        ),
      ),
    );
    if (mounted) await load();
  }

  TextStyle _style(
    double size, {
    Color color = _ink,
    FontWeight weight = FontWeight.w400,
    double? spacing,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    color: context.themeForeground(color),
    fontWeight: weight,
    letterSpacing: spacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  BoxDecoration _surface({double radius = 16}) => BoxDecoration(
    color: context.themeSurface(Colors.white),
    border: Border.all(color: context.themeOutline(_line)),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(color: Color(0x080F1930), offset: Offset(0, 1), blurRadius: 2),
    ],
  );

  Widget _kpi(String label, String value, String description) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: _surface(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _style(13, color: _sub, weight: FontWeight.w700, spacing: 1.1),
        ),
        const SizedBox(height: 6),
        Text(value, style: _style(28, weight: FontWeight.w600, spacing: -.8)),
        const SizedBox(height: 6),
        Text(description, style: _style(13, color: _sub)),
      ],
    ),
  );

  Widget _filters(int needsDecision, int decided) => Wrap(
    spacing: 10,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: TextField(
          style: _style(13),
          decoration: InputDecoration(
            hintText: 'Search name or role',
            hintStyle: _style(13, color: _muted),
            filled: true,
            fillColor: context.themeSurface(Colors.white),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: _searchBorder(_line),
            enabledBorder: _searchBorder(_line),
            focusedBorder: _searchBorder(const Color(0xFF3E6FF0)),
          ),
          onChanged: (value) => setState(() => search = value),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: context.themeSurface(const Color(0xFFEAEFF7)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Wrap(
            children: [
              for (final (option, count) in [
                (_InterviewFilter.all, interviews.length),
                (_InterviewFilter.needsDecision, needsDecision),
                (_InterviewFilter.decided, decided),
              ])
                Semantics(
                  selected: filter == option,
                  child: Material(
                    color: filter == option
                        ? context.themeSurface(Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => filter = option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          '${option.label} · ${loading && interviews.isEmpty ? '—' : count}',
                          style: _style(
                            13,
                            color: filter == option ? _ink : _sub,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  OutlineInputBorder _searchBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.themeOutline(color)),
  );

  Widget _badge(String label, Color background, Color foreground) => Align(
    alignment: Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.themeSurface(background),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          label,
          style: _style(
            12,
            color: foreground,
            weight: FontWeight.w700,
            spacing: .45,
          ),
        ),
      ),
    ),
  );

  Widget _decisionBadge(RecruiterInterview interview) {
    final candidate = candidates[interview.applicationId];
    if (!latestAttempts.contains(interview.id)) {
      return _badge('EARLIER ATTEMPT', const Color(0xFFEEF2F8), _sub);
    }
    return switch (candidate?.$2?.outcome) {
      'HIRE' => _badge(
        'HIRE',
        const Color(0xFFE4F5F0),
        const Color(0xFF067A63),
      ),
      'REJECT' => _badge(
        'REJECT',
        const Color(0xFFFCEEF0),
        const Color(0xFFA52F43),
      ),
      _ when _needsDecision(interview) => _badge(
        'NEEDS DECISION',
        const Color(0xFFFFF3DC),
        const Color(0xFF8A5A00),
      ),
      _ => _badge(
        candidate == null || candidate.$2?.legacy == true
            ? 'UNAVAILABLE'
            : 'PENDING',
        const Color(0xFFEEF2F8),
        _sub,
      ),
    };
  }

  Widget _candidateCell(RecruiterInterview interview) {
    final application = candidates[interview.applicationId]?.$1;
    final name = application?.candidateName?.trim();
    final email = application?.candidateEmail ?? '';
    final displayName = name != null && name.isNotEmpty
        ? name
        : email.isNotEmpty
        ? email
        : 'Candidate unavailable';
    final initials =
        application == null || (name?.isEmpty != false && email.isEmpty)
        ? '?'
        : displayName
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();
    const palette = [
      (Color(0xFFEAF0FF), Color(0xFF2C52C4)),
      (Color(0xFFE4F5F0), Color(0xFF067A63)),
      (Color(0xFFFCEEF0), Color(0xFFA52F43)),
    ];
    final index =
        interview.applicationId.codeUnits.fold(
          0,
          (total, code) => total + code,
        ) %
        palette.length;
    final (fill, ink) = palette[index];
    final role = application?.jobTitle ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: context.themeSurface(fill),
          child: Text(
            initials,
            style: _style(13, color: ink, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _twoLines(
            displayName,
            role.isEmpty ? 'Role unavailable' : role,
          ),
        ),
      ],
    );
  }

  Widget _twoLines(String primary, String secondary) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        primary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style(14, weight: FontWeight.w600),
      ),
      if (secondary.isNotEmpty)
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(13, color: _muted),
        ),
    ],
  );

  Widget _dateCell(RecruiterInterview interview) {
    final date = (interview.completedAt ?? interview.scheduledAt)?.toLocal();
    if (date == null) return _twoLines('Unavailable', '');
    final localizations = MaterialLocalizations.of(context);
    return _twoLines(
      localizations.formatMediumDate(date),
      localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(date),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    );
  }

  List<Widget> _cells(RecruiterInterview interview) {
    final usable = interview.completionOutcome == 'USABLE';
    final score = scores[interview.id];
    return [
      _candidateCell(interview),
      _dateCell(interview),
      _badge(
        interview.completionOutcome.replaceAll('_', ' '),
        usable ? const Color(0xFFE4F5F0) : const Color(0xFFFFF3DC),
        usable ? const Color(0xFF067A63) : const Color(0xFF8A5A00),
      ),
      Text(_percent(score), style: _style(14, weight: FontWeight.w700)),
      _decisionBadge(interview),
      Align(
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_right,
          size: 17,
          color: context.themeForeground(_muted),
        ),
      ),
    ];
  }

  String _percent(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}%';

  Widget _tableLine(List<Widget> cells, {required bool header}) => Container(
    constraints: BoxConstraints(minHeight: header ? 40 : 66),
    decoration: BoxDecoration(
      color: header ? context.themeSurface(const Color(0xFFF7F8FA)) : null,
      border: Border(
        bottom: BorderSide(
          color: context.themeOutline(header ? _line : _separator),
        ),
      ),
    ),
    child: Row(
      children: [
        for (final (index, cell) in cells.indexed)
          Expanded(
            flex: _columns[index],
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: index == 5 ? 6 : 20,
                vertical: 9,
              ),
              child: cell,
            ),
          ),
      ],
    ),
  );

  Widget _table(List<RecruiterInterview> rows, double maxHeight) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: _surface(),
    child: LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 870 ? 870 : constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tableLine([
                for (final heading in [
                  'CANDIDATE',
                  'INTERVIEW',
                  'STATUS',
                  'COMBINED SCORE',
                  'DECISION',
                  '',
                ])
                  Text(
                    heading,
                    style: _style(
                      11.5,
                      color: _sub,
                      weight: FontWeight.w700,
                      spacing: 1,
                    ),
                  ),
              ], header: true),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(26),
                  child: Text(
                    loading
                        ? 'Loading interviews…'
                        : error != null
                        ? 'Could not load interviews.'
                        : interviews.isEmpty
                        ? 'No interviews available.'
                        : 'No interviews match your search or filter.',
                    style: _style(14, color: _sub),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final interview = rows[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _open(interview),
                          hoverColor: context.themeSurface(
                            const Color(0xFFF7F9FD),
                          ),
                          child: _tableLine(_cells(interview), header: false),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rows = interviews.where(_matches).toList();
    final needsDecision = interviews.where(_needsDecision).length;
    final completed = interviews
        .where((interview) => interview.status == 'DONE')
        .length;
    final decided = interviews.where(_decided).length;
    final average = scores.isEmpty
        ? null
        : scores.values.reduce((left, right) => left + right) / scores.length;
    String count(int value) => loading && interviews.isEmpty ? '—' : '$value';

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
          ? const RecruiterMobileNav(
              currentRoute: '/recruiter/interview-review',
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            InterviewReviewTopBar(
              onRefresh: loading || notFound || token.isCancelled ? null : load,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final width = bounds.maxWidth.clamp(0.0, 1560.0).toDouble();
                  final padding = (width * .02).clamp(14.0, 28.0).toDouble();
                  final perRow = width >= 900
                      ? 4
                      : width >= 530
                      ? 2
                      : 1;
                  final cardWidth =
                      (width - 2 * padding - (perRow - 1) * _gap) / perRow;
                  return SingleChildScrollView(
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            14,
                            padding,
                            28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Interview evidence and decisions',
                                style: pageHeadingStyle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Open an interview to review evidence, scores and record a decision.',
                                style: _style(14, color: _sub),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: _gap,
                                runSpacing: _gap,
                                children: [
                                  for (final (label, value, description) in [
                                    (
                                      'NEEDS DECISION',
                                      count(needsDecision),
                                      'Evaluated and waiting for you',
                                    ),
                                    (
                                      'COMPLETED INTERVIEWS',
                                      count(completed),
                                      'Ready for review',
                                    ),
                                    (
                                      'DECIDED',
                                      count(decided),
                                      'Hire or reject recorded',
                                    ),
                                    (
                                      'AVERAGE COMBINED SCORE',
                                      _percent(average),
                                      'Across all completed interviews',
                                    ),
                                  ])
                                    SizedBox(
                                      width: cardWidth,
                                      child: _kpi(label, value, description),
                                    ),
                                ],
                              ),
                              const SizedBox(height: _gap),
                              _filters(needsDecision, decided),
                              const SizedBox(height: _gap),
                              if (loading)
                                const LinearProgressIndicator(minHeight: 2),
                              if (error != null)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        error!,
                                        style: _style(13, color: _sub),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: notFound || token.isCancelled
                                          ? null
                                          : load,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              _table(
                                rows,
                                (bounds.maxHeight - 335)
                                    .clamp(138.0, 660.0)
                                    .toDouble(),
                              ),
                            ],
                          ),
                        ),
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
}
