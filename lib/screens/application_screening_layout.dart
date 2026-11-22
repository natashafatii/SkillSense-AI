part of 'application_screening_screen.dart';

const _muted = ScreeningStyle.muted;
const _line = ScreeningStyle.line;
const _blue = ScreeningStyle.blue;
const _green = ScreeningStyle.green;
const _accent = ScreeningStyle.accent;
const _link = ScreeningButtonKind.link;
const _primary = ScreeningButtonKind.primary;

String _label(Object? value, [String fallback = 'Unavailable']) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return fallback;
  if (text != text.toUpperCase()) return text;
  final words = text.toLowerCase().replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

String _screeningCount(int amount, {bool capitalized = true}) {
  const small = [
    '',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
  ];
  if (amount < 1 || amount >= small.length) return amount.toString();
  final word = small[amount];
  return capitalized ? word[0].toUpperCase() + word.substring(1) : word;
}

String _number(double value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

String _date(DateTime date) {
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
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _name(Application app) => app.candidateName?.trim().isNotEmpty == true
    ? app.candidateName!.trim()
    : app.candidateEmail;

String _job(Application app) =>
    [app.jobTitle, app.jobCompany].where((part) => part.isNotEmpty).join(' · ');

Widget _copy(
  String value, {
  double size = 12.5,
  int weight = 400,
  Color color = _muted,
}) => Text(
  value,
  style: ScreeningStyle.text(size, weight: weight, color: color),
);

Widget _screeningStack(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (index, child) in children.indexed) ...[
      if (index != 0) const SizedBox(height: 14),
      child,
    ],
  ],
);

class _ScreeningWorkspace extends StatefulWidget {
  const _ScreeningWorkspace({
    required this.app,
    required this.error,
    required this.busy,
    required this.acknowledge,
    required this.needsReview,
    required this.refresh,
    required this.reason,
    required this.action,
    required this.interview,
    required this.schedule,
    required this.canAct,
  });

  final Application? app;
  final String? error;
  final bool busy, needsReview;
  final VoidCallback? acknowledge, refresh;
  final TextEditingController reason;
  final ValueChanged<String> action;
  final VoidCallback interview, schedule;
  final bool Function(String) canAct;

  @override
  State<_ScreeningWorkspace> createState() => _ScreeningWorkspaceState();
}

class _ScreeningWorkspaceState extends State<_ScreeningWorkspace> {
  final _requirements = GlobalKey(),
      _decision = GlobalKey(),
      _history = GlobalKey(),
      _questions = GlobalKey();
  final _desktopColumns = GlobalKey();
  Future<ResumeDetail>? _resume;
  bool _technical = false, _reasonError = false, _approved = false;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  @override
  void didUpdateWidget(covariant _ScreeningWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app?.resumeId != widget.app?.resumeId) _loadResume();
    if (widget.app?.status != ApplicationStatus.screened) _approved = false;
  }

  void _loadResume() {
    final id = widget.app?.resumeId;
    _resume = id == null || id.isEmpty
        ? null
        : ResumeService.getResumeDetail(id);
  }

  void _jump(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  void _search() {
    final sections = {
      'Requirement evidence': _requirements,
      'Recruiter screening decision': _decision,
      'Screening history': _history,
      'Interview questions': _questions,
    };
    showScreeningSearch(context, {
      for (final entry in sections.entries)
        if (entry.value.currentContext != null)
          entry.key: () => _jump(entry.value),
      if (widget.app != null && !widget.busy)
        'Interview evidence & decisions': widget.interview,
    });
  }

  String _resumeMeta(ResumeDetail? resume) {
    final bytes = resume?.fileSize;
    final uploaded = resume?.uploadedAt;
    return [
      if (uploaded != null) 'Uploaded ${_date(uploaded)}',
      if (bytes != null)
        if (bytes < 1024)
          '$bytes B'
        else if (bytes < 1048576)
          '${(bytes / 1024).toStringAsFixed(1)} KB'
        else
          '${(bytes / 1048576).toStringAsFixed(1)} MB',
    ].join(' · ');
  }

  void _showResume(ScreeningAssessment? evidence) => showScreeningDialog(
    context,
    title: 'Resume evidence',
    child: FutureBuilder<ResumeDetail>(
      future: _resume,
      builder: (context, snapshot) {
        final resume = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(minHeight: 2)
            else if (resume == null)
              const Text('Resume file details are unavailable.')
            else ...[
              Text(
                resume.filename ?? 'Submitted resume',
                style: ScreeningStyle.title(13),
              ),
              Text(_resumeMeta(resume)),
            ],
            const SizedBox(height: 16),
            Text('Skills used in screening', style: ScreeningStyle.title(13)),
            const SizedBox(height: 6),
            Text(
              evidence?.matchedSkills.isNotEmpty == true
                  ? evidence!.matchedSkills.join(' · ')
                  : 'No matched skills recorded.',
            ),
            if (resume?.skills case final skills? when skills.isNotEmpty)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  expandedAlignment: Alignment.centerLeft,
                  title: Text(
                    'All extracted skills (${skills.length})',
                    style: ScreeningStyle.text(12.5, weight: 600, color: _blue),
                  ),
                  children: [Text(skills.join(' · '))],
                ),
              ),
            if (resume != null)
              Align(
                alignment: Alignment.centerRight,
                child: ScreeningButton(
                  'Download resume',
                  kind: _primary,
                  onPressed: () async {
                    try {
                      await downloadResume(
                        resume.id,
                        resume.filename ?? 'Resume',
                      );
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not download resume. Please try again.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _identity(Application app) {
    final initials = _name(app)
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ScreeningStyle.tint,
            borderRadius: BorderRadius.circular(13),
          ),
          child: _copy(initials, size: 14, weight: 700, color: _blue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name(app), style: ScreeningStyle.title()),
              const SizedBox(height: 2),
              _copy(app.jobTitle, size: 12),
            ],
          ),
        ),
      ],
    );
  }

  void _showApplication(
    Application app,
    ScreeningAssessment? evidence,
  ) => showScreeningDialog(
    context,
    title: 'Applicant · ${_name(app)}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _identity(app),
        const SizedBox(height: 16),
        Text('Application', style: ScreeningStyle.title(13)),
        const SizedBox(height: 6),
        Text(
          '${_job(app)}\nApplied ${_date(app.createdAt)} · ${_label(app.rawStatus ?? app.status.value)}',
        ),
        if (app.coverNote case final note? when note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Cover note', style: ScreeningStyle.title(13)),
          Text(note),
        ],
        if (app.resumeId != null) ...[
          const SizedBox(height: 16),
          Text('Resume', style: ScreeningStyle.title(13)),
          const SizedBox(height: 6),
          FutureBuilder<ResumeDetail>(
            future: _resume,
            builder: (context, snapshot) {
              final resume = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              final meta = _resumeMeta(resume);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      resume?.filename ?? 'Submitted resume',
                      if (meta.isNotEmpty) meta,
                    ].join(' · '),
                  ),
                  if (resume?.skills case final skills?
                      when skills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Extracted skills', style: ScreeningStyle.title(13)),
                    const SizedBox(height: 6),
                    Text(skills.take(10).join(' · ')),
                  ],
                ],
              );
            },
          ),
          Builder(
            builder: (dialogContext) => ScreeningButton(
              'View resume details',
              kind: _link,
              onPressed: () {
                Navigator.pop(dialogContext);
                _showResume(evidence);
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Builder(
            builder: (dialogContext) => ScreeningButton(
              'Return to screening evidence',
              kind: _primary,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final evidence = app?.screening;
    return Scaffold(
      backgroundColor: ScreeningStyle.canvas,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _search,
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _search,
        },
        child: Focus(
          autofocus: true,
          child: CustomPaint(
            painter: const ScreeningBackground(),
            child: SafeArea(
              child: DefaultTextStyle(
                style: ScreeningStyle.text(13),
                child: Column(
                  children: [
                    ScreeningCommandBar(
                      onSearch: _search,
                      section: 'Application screening',
                    ),
                    if (widget.busy)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: _accent,
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, viewport) {
                          final width = viewport.maxWidth;
                          final gutter = ScreeningStyle.gutter(width);
                          final titleSize = (width * .024).clamp(22.0, 26.0);
                          final heading = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Screening evidence',
                                style: ScreeningStyle.text(
                                  titleSize,
                                  weight: 800,
                                  height: 1.15,
                                  spacing: -titleSize * .03,
                                ),
                              ),
                              if (app != null) ...[
                                const SizedBox(height: 4),
                                _copy(_job(app), size: 13, weight: 500),
                              ],
                            ],
                          );
                          final refresh = ScreeningButton(
                            'Refresh application',
                            glyph: ScreeningGlyph.refresh,
                            onPressed: widget.refresh,
                          );
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              14,
                              gutter,
                              40,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: Navigator.of(context).canPop()
                                        ? () => Navigator.of(context).maybePop()
                                        : app == null
                                        ? null
                                        : () => _showApplication(app, evidence),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _muted,
                                      minimumSize: const Size(0, 28),
                                      padding: EdgeInsets.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: ScreeningStyle.text(
                                        12.5,
                                        weight: 600,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ScreeningIcon(
                                          ScreeningGlyph.back,
                                          color: _muted,
                                        ),
                                        SizedBox(width: 6),
                                        Text('Back to application'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (width <= 640) ...[
                                  heading,
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: refresh,
                                  ),
                                ] else
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(child: heading),
                                      const SizedBox(width: 12),
                                      refresh,
                                    ],
                                  ),
                                const SizedBox(height: 14),
                                if (widget.error case final error?) ...[
                                  _copy(
                                    error,
                                    size: 13,
                                    weight: 600,
                                    color: ScreeningStyle.red,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (widget.needsReview)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ScreeningButton(
                                      'I reviewed the refreshed application',
                                      onPressed: widget.acknowledge,
                                    ),
                                  ),
                                if (app != null)
                                  _content(app, evidence, width)
                                else if (widget.error == null)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                if (app?.status ==
                                    ApplicationStatus.screened) ...[
                                  const SizedBox(height: 16),
                                  KeyedSubtree(
                                    key: _questions,
                                    child: QuestionPreparationPanel(
                                      key: ValueKey('preparation-${app!.id}'),
                                      applicationId: app.id,
                                      application: app,
                                      onSchedule: widget.schedule,
                                      onApprovalChanged: (id, revision) {
                                        final approved =
                                            id != null && revision != null;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted &&
                                                  _approved != approved &&
                                                  widget.app?.status ==
                                                      ApplicationStatus
                                                          .screened) {
                                                setState(
                                                  () => _approved = approved,
                                                );
                                              }
                                            });
                                      },
                                    ),
                                  ),
                                ],
                              ],
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
        ),
      ),
    );
  }

  Widget _content(
    Application app,
    ScreeningAssessment? evidence,
    double width,
  ) {
    final canDecide = app.allowedActions.any(
      (action) => action == 'shortlist' || action == 'reject',
    );
    final recorded = app.history
        .where(
          (event) =>
              event['source'] == 'MANUAL' &&
              const {'SHORTLISTED', 'REJECTED'}.contains(event['to_status']),
        )
        .firstOrNull;
    final score = evidence?.pending == true || evidence?.status == 'FAILED'
        ? null
        : evidence?.matchScore ?? app.resumeScore;
    final sidebar = [
      ScreeningPanel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _identity(app),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: _line),
                  ),
                ),
                child: Column(
                  children: [
                    _fact(
                      'Application stage',
                      _label(app.rawStatus ?? app.status.value),
                    ),
                    const SizedBox(height: 9),
                    _fact('Applied', _date(app.createdAt)),
                    const SizedBox(height: 9),
                    _fact('Policy recommendation', _label(evidence?.outcome)),
                  ],
                ),
              ),
              FutureBuilder<ResumeDetail>(
                future: _resume,
                builder: (context, snapshot) {
                  final resume = snapshot.data;
                  return InkWell(
                    onTap: app.resumeId == null
                        ? null
                        : () => _showResume(evidence),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const ScreeningIcon(
                              ScreeningGlyph.file,
                              color: _blue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _copy(
                                  resume?.filename ??
                                      (app.resumeId == null
                                          ? 'No resume attached'
                                          : 'Submitted resume'),
                                  weight: 700,
                                  color: ScreeningStyle.ink,
                                ),
                                if (_resumeMeta(resume) case final meta
                                    when meta.isNotEmpty)
                                  _copy(meta, size: 11.5, weight: 500),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              ScreeningButton(
                'View application details',
                kind: _link,
                onPressed: () => _showApplication(app, evidence),
              ),
            ],
          ),
        ),
      ),
      _next(app, evidence, canDecide, recorded != null),
    ];
    final main = _screeningStack([
      _ScreeningOutcome(evidence: evidence, score: score, canDecide: canDecide),
      _RequirementEvidence(
        key: _requirements,
        criteria: evidence?.criteria ?? const [],
        failed: evidence?.status == 'FAILED',
        onResume: () => _showResume(evidence),
      ),
      if (canDecide || recorded != null)
        KeyedSubtree(
          key: _decision,
          child: _decisionPanel(app, evidence, score, recorded, canDecide),
        ),
      _ScreeningHistory(key: _history, app: app, assessment: evidence),
      _processing(app, evidence),
    ]);
    if (width > 900) {
      return Row(
        key: _desktopColumns,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: main),
          const SizedBox(width: 16),
          SizedBox(
            width: width <= 1100 ? 290 : 320,
            child: ScreeningStickyAside(
              section: _desktopColumns,
              child: _screeningStack(sidebar),
            ),
          ),
        ],
      );
    }
    return _screeningStack([
      if (width > 640)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: sidebar.first),
            const SizedBox(width: 14),
            Expanded(child: sidebar.last),
          ],
        )
      else
        _screeningStack(sidebar),
      main,
    ]);
  }

  Widget _next(
    Application app,
    ScreeningAssessment? evidence,
    bool canDecide,
    bool recorded,
  ) {
    final missing = evidence?.missingSkills.length ?? 0;
    final (title, message, action, VoidCallback? callback) = switch ((
      app.eligibleForInterview,
      app.status,
      evidence?.pending == true,
      app.allowedActions.contains('retry-screening'),
      canDecide,
      recorded,
    )) {
      (true, _, _, _, _, _) => (
        'Ready for interview preparation',
        'This applicant is eligible for scheduling. Review the interview questions before choosing a time.',
        _approved ? 'Schedule interview' : 'Review interview questions',
        widget.busy
            ? null
            : _approved || app.status != ApplicationStatus.screened
            ? widget.schedule
            : () => _jump(_questions),
      ),
      (_, ApplicationStatus.scheduled, _, _, _, _) => (
        'Interview scheduled',
        'Open the interview record for this application.',
        'View scheduled interview',
        widget.busy ? null : widget.interview,
      ),
      (_, _, true, _, _, _) => (
        'Awaiting screening',
        'Interview preparation will become available when the applicant is eligible.',
        'Screening in progress',
        null,
      ),
      (_, _, _, true, _, _) => (
        'Recover the assessment',
        'Review the processing details and follow the recovery guidance.',
        'Retry screening',
        widget.canAct('retry-screening')
            ? () => widget.action('retry-screening')
            : null,
      ),
      (_, _, _, _, true, _) => (
        'Screening decision needed',
        missing == 0
            ? 'Review the unverified requirements and record a rationale for your decision.'
            : 'Review the ${_screeningCount(missing, capitalized: false)} unverified ${missing == 1 ? 'skill' : 'skills'}. Record a rationale to manually shortlist or reject this application.',
        'Review screening decision',
        () => _jump(_decision),
      ),
      (_, _, _, _, _, true) => (
        'Screening decision recorded',
        'Review the recruiter’s screening decision and rationale.',
        'View screening decision',
        () => _jump(_decision),
      ),
      _ => (
        'Application status',
        'Review the recorded evidence and screening history for this applicant.',
        'View screening history',
        () => _jump(_history),
      ),
    };
    return ScreeningPanel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ScreeningStyle.title(15)),
            const SizedBox(height: 6),
            Text(
              message,
              style: ScreeningStyle.text(12.5, color: _muted, height: 1.55),
            ),
            const SizedBox(height: 12),
            ScreeningButton(
              action,
              kind: _primary,
              stretch: true,
              onPressed: callback,
            ),
            const SizedBox(height: 8),
            ScreeningButton(
              'Interview evidence & decisions',
              kind: _link,
              onPressed: widget.busy ? null : widget.interview,
            ),
          ],
        ),
      ),
    );
  }

  Widget _decisionPanel(
    Application app,
    ScreeningAssessment? evidence,
    double? score,
    Map<String, dynamic>? recorded,
    bool canDecide,
  ) {
    final threshold = evidence?.threshold;
    final below = score != null && threshold != null && score < threshold;
    final missing = evidence?.missingSkills ?? const <String>[];
    final unverified = missing.isNotEmpty
        ? missing
        : [
            for (final row
                in evidence?.criteria ?? const <ScreeningCriterion>[])
              if (row.status != 'PASS' && row.requirement.isNotEmpty)
                row.requirement,
          ];
    final inset = ScreeningStyle.inset(context);
    return ScreeningPanel(
      tint: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreeningHeading(
            'Recruiter screening decision',
            'Review missing evidence before recording an outcome.',
            action: ScreeningButton(
              'Review resume details',
              kind: _link,
              onPressed: () => _showResume(evidence),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unverified.isNotEmpty) ...[
                  _copy(
                    missing.isEmpty
                        ? 'Requirements needing review'
                        : 'Skills not evidenced in the resume',
                    size: 12,
                    weight: 700,
                    color: ScreeningStyle.ink,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in unverified)
                        _DashedCard(
                          radius: 99,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            child: _copy(
                              item,
                              size: 12,
                              weight: 700,
                              color: const Color(0xff334a7a),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                _copy(
                  below
                      ? 'Screening match ${_number(score)} / 100 is below the policy threshold of ${_number(threshold)}. You can record a manual screening decision with your rationale.'
                      : 'Review the unverified requirements before recording a screening decision.',
                ),
                const SizedBox(height: 16),
                if (recorded != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _copy(
                          recorded['to_status'] == 'REJECTED'
                              ? 'Manually rejected'
                              : 'Manually shortlisted',
                          size: 13,
                          weight: 700,
                          color: ScreeningStyle.ink,
                        ),
                        const SizedBox(height: 4),
                        _copy('${recorded['reason'] ?? ''}'),
                      ],
                    ),
                  ),
                  if (canDecide) const SizedBox(height: 12),
                ],
                if (canDecide) ...[
                  const SizedBox(height: 10),
                  _copy(
                    'Reason for screening override or rejection',
                    weight: 700,
                    color: ScreeningStyle.ink,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: widget.reason,
                    enabled: !widget.busy,
                    minLines: 3,
                    maxLines: 3,
                    maxLength: 2000,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    style: ScreeningStyle.text(12.5, weight: 500),
                    decoration: ScreeningStyle.field(
                      hint:
                          'Explain the evidence or reasoning behind your decision.',
                    ),
                    onChanged: (_) {
                      if (_reasonError) setState(() => _reasonError = false);
                    },
                  ),
                  const SizedBox(height: 6),
                  _copy(
                    'This rationale will be recorded in screening history.',
                    size: 11.5,
                    weight: 500,
                  ),
                  if (_reasonError) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: _copy(
                        'Enter a reason before shortlisting or rejecting.',
                        size: 13,
                        weight: 600,
                        color: ScreeningStyle.red,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (app.allowedActions.contains('shortlist'))
                        ScreeningButton(
                          'Shortlist applicant',
                          kind: _primary,
                          onPressed: widget.canAct('shortlist')
                              ? () => _decide('shortlist')
                              : null,
                        ),
                      if (app.allowedActions.contains('reject'))
                        ScreeningButton(
                          'Reject application',
                          kind: ScreeningButtonKind.danger,
                          onPressed: widget.canAct('reject')
                              ? () => _decide('reject')
                              : null,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _decide(String action) {
    if (widget.reason.text.trim().isEmpty) {
      setState(() => _reasonError = true);
    } else {
      widget.action(action);
    }
  }

  Widget _processing(Application app, ScreeningAssessment? evidence) {
    final entries = <(String, String)>[
      ('Assessment revision', evidence?.revision.toString() ?? 'Unavailable'),
      ('Screening policy', evidence?.policyVersion ?? 'Unavailable'),
      ('Processing status', _label(evidence?.status, 'Awaiting assessment')),
      ('Required criteria', _label(evidence?.eligibility)),
      (
        'Policy threshold',
        switch (evidence?.threshold) {
          final threshold? => '${_number(threshold)} / 100',
          null => 'Unavailable',
        },
      ),
      (
        'Interview eligibility',
        app.eligibleForInterview
            ? 'Eligible · no existing interview'
            : 'Not currently eligible',
      ),
      if (evidence != null && evidence.attempts > 0)
        ('Attempts', '${evidence.attempts}'),
      if (evidence?.errorCode.isNotEmpty == true)
        ('Error code', evidence!.errorCode),
    ];
    return ScreeningPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ScreeningStyle.inset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: _technical,
              button: true,
              child: InkWell(
                onTap: () => setState(() => _technical = !_technical),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: _copy(
                          'Assessment & processing details',
                          size: 13,
                          weight: 700,
                          color: ScreeningStyle.ink,
                        ),
                      ),
                      RotatedBox(
                        quarterTurns: _technical ? 2 : 0,
                        child: const ScreeningIcon(ScreeningGlyph.chevron),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_technical) ...[
              LayoutBuilder(
                builder: (context, size) {
                  final columns = ((size.maxWidth + 12) / 182).floor().clamp(
                    1,
                    entries.length,
                  );
                  final width = (size.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (label, value) in entries)
                        SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _copy(label, size: 11.5, weight: 600),
                              const SizedBox(height: 2),
                              _copy(
                                value,
                                weight: 600,
                                color: ScreeningStyle.ink,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _copy(
                'Recovery · ${_label(evidence?.recoveryAction, 'Wait')}',
                size: 12,
              ),
              if (evidence?.reasons.isNotEmpty == true)
                _copy(
                  'Assessment reasons · ${evidence!.reasons.map((reason) => _label(reason)).join(' · ')}',
                  size: 12,
                ),
              if (evidence?.matchedSkills.isNotEmpty == true)
                _copy(
                  'Matched skills · ${evidence!.matchedSkills.join(' · ')}',
                  size: 12,
                ),
              if (evidence?.missingSkills.isNotEmpty == true)
                _copy(
                  'Missing skills · ${evidence!.missingSkills.join(' · ')}',
                  size: 12,
                ),
              if (evidence?.errorMessage.isNotEmpty == true)
                _copy(
                  evidence!.errorMessage,
                  size: 12,
                  color: ScreeningStyle.red,
                ),
              if (app.allowedActions.contains('rescreen'))
                Align(
                  alignment: Alignment.centerLeft,
                  child: ScreeningButton(
                    'Rescreen with current policy',
                    onPressed: widget.canAct('rescreen')
                        ? () => widget.action('rescreen')
                        : null,
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _fact(String label, String value) => LayoutBuilder(
  builder: (context, bounds) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _copy(label, weight: 500)),
      const SizedBox(width: 12),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bounds.maxWidth / 2),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: ScreeningStyle.text(12.5, weight: 700),
        ),
      ),
    ],
  ),
);
