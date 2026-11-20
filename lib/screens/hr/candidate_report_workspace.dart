part of 'candidate_report_screen.dart';

typedef _InterviewEvidence = ({
  EvaluationRevision? evaluation,
  TranscriptRevision? transcript,
  bool transcriptUnavailable,
  bool pending,
});

class _ReportPalette {
  const _ReportPalette(this.dark);
  final bool dark;

  Color get canvas => dark ? const Color(0xff070b14) : const Color(0xfff6f8fe);
  Color get ink => dark ? const Color(0xffe7ecf6) : const Color(0xff1b2740);
  Color get muted => dark ? const Color(0xff9facc6) : const Color(0xff4a5875);
  Color get border => dark ? const Color(0x2994aadc) : const Color(0x2126334d);
  Color get paper => dark ? const Color(0xff0c1322) : Colors.white;
  Color get field => dark ? const Color(0xff131d2f) : const Color(0xfff7f9fd);
  Color get rail => dark ? const Color(0xff090e19) : const Color(0xfff8faff);
  Color get goodInk => dark ? const Color(0xff5ff0c4) : const Color(0xff0b6b4a);
  Color get goodField =>
      dark ? const Color(0x1f34e3b0) : const Color(0xffd9f4e7);
  Color get warningField =>
      dark ? const Color(0x1ff5b14b) : const Color(0xfffbeed2);
  List<Color> get primary => dark
      ? const [Color(0xff486fda), Color(0xff4055e8)]
      : const [Color(0xff335cd0), Color(0xff2e4fe0)];
  Color get soft => dark ? const Color(0x246c9bff) : const Color(0xffe3ebfe);
  Color get blue => dark ? const Color(0xff6c9bff) : const Color(0xff3e6ff0);
  Color get accent => dark ? const Color(0xffa7c1ff) : const Color(0xff2743a8);
  Color get mint => dark ? const Color(0xff34e3b0) : const Color(0xff10a778);
  Color get amber => dark ? const Color(0xffffce85) : const Color(0xff8a5d10);
  Color get track => dark ? const Color(0x2194aadc) : const Color(0xffe3e9f4);
}

TextStyle _reportDisplay(double size) => TextStyle(
  fontFamily: 'Space Grotesk',
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: -size * .025,
  height: 1.15,
);

class _ReportWorkspace extends StatelessWidget {
  const _ReportWorkspace({
    required this.palette,
    required this.data,
    required this.decisionKey,
    required this.screeningKey,
    required this.interviewKey,
    required this.answersKey,
    required this.viewport,
    required this.interview,
    required this.evidence,
    required this.evidenceLoading,
    required this.evidenceError,
    required this.rank,
    required this.candidateCount,
    required this.onPrevious,
    required this.onNext,
    required this.onReview,
    required this.onSchedule,
    required this.onManage,
    required this.onRefresh,
    required this.onRetryEvidence,
    required this.onDecision,
  });

  final _ReportPalette palette;
  final _ReportData data;
  final GlobalKey decisionKey, screeningKey, interviewKey, answersKey;
  final double viewport;
  final RecruiterInterview? interview;
  final _InterviewEvidence? evidence;
  final bool evidenceLoading, evidenceError;
  final int? rank;
  final int candidateCount;
  final VoidCallback? onPrevious, onNext, onRefresh, onSchedule, onManage;
  final VoidCallback onReview, onRetryEvidence, onDecision;

  EvaluationRevision? get _readyEvaluation {
    final evaluation = evidence?.evaluation;
    return evaluation?.status == 'READY' && evaluation?.publishedAt != null
        ? evaluation
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = _readyEvaluation;
    final answers = {
      for (final answer in evaluation?.answers ?? const <AnswerResult>[])
        answer.questionId: answer,
    };
    final questions = evaluation == null
        ? const <InterviewQuestion>[]
        : evaluation.questions.isNotEmpty
        ? evaluation.questions
        : interview?.questions ?? const <InterviewQuestion>[];
    final profile = _profile(context, evaluation?.score);
    final decision = _decision();
    final summary = _summary(context, evaluation);
    final performance = _performance(context, questions, answers);
    final screening = _screening(context);
    final excerpts = _answers(context, questions, answers);
    final followups = _followups(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scaled = MediaQuery.textScalerOf(context).scale(14);
        final compact = viewport <= 760 || width < 550 || scaled > 18;
        final wide = viewport > 1120 && width >= 940 && scaled <= 16;
        final profileWidth = wide
            ? ((width - _workspaceGap * 2) * 1.08 / 3.08).clamp(270.0, width)
            : ((width - _workspaceGap) * .85 / 2.10).clamp(250.0, width);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact) ...[
              profile,
              const SizedBox(height: _workspaceGap),
              decision,
              const SizedBox(height: _workspaceGap),
              summary,
              const SizedBox(height: _workspaceGap),
              performance,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: profileWidth, child: profile),
                  const SizedBox(width: _workspaceGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        decision,
                        const SizedBox(height: _workspaceGap),
                        if (wide)
                          _paired(summary, performance)
                        else ...[
                          summary,
                          const SizedBox(height: _workspaceGap),
                          performance,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: _workspaceGap),
            screening,
            const SizedBox(height: _workspaceGap),
            if (compact) ...[
              excerpts,
              const SizedBox(height: _workspaceGap),
              followups,
            ] else
              _paired(followups, excerpts, firstWidth: profileWidth),
          ],
        );
      },
    );
  }

  Widget _paired(Widget first, Widget second, {double? firstWidth}) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (firstWidth != null)
              SizedBox(width: firstWidth, child: first)
            else
              Expanded(child: first),
            const SizedBox(width: _workspaceGap),
            Expanded(child: second),
          ],
        ),
      );

  Widget _panel(
    String title,
    Widget content, {
    Key? key,
    String? subtitle,
    Widget? status,
  }) => _WorkspaceCard(
    key: key,
    palette: palette,
    title: title,
    subtitle: subtitle,
    status: status,
    child: content,
  );

  Widget _profile(BuildContext context, double? score) {
    final app = data.application;
    final name = _candidateName(app);
    final initials = _initials(app.candidateName ?? app.candidateEmail);
    final screening = app.resumeScore ?? data.assessment?.matchScore;
    return _WorkspaceCard(
      palette: palette,
      profile: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ReportAvatar(palette: palette, size: 43, label: initials),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: _reportDisplay(23)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (app.jobTitle.trim().isNotEmpty)
                          Text(
                            app.jobTitle,
                            style: _secondary(
                              12,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        Text(
                          'Applied ${_date(context, app.createdAt)}',
                          style: _secondary(12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: _InterviewScore(palette: palette, score: score),
          ),
          const SizedBox(height: 10),
          Text(
            'Interview score',
            textAlign: TextAlign.center,
            style: _reportDisplay(14),
          ),
          if (interview?.completedAt case final completed?) ...[
            const SizedBox(height: 3),
            Text(
              'Completed ${_date(context, completed)}',
              textAlign: TextAlign.center,
              style: _secondary(11),
            ),
          ],
          if (score == null)
            Text(
              evidenceLoading
                  ? 'Loading interview evaluation…'
                  : 'Score unavailable',
              textAlign: TextAlign.center,
              style: _secondary(11),
            ),
          const SizedBox(height: 17),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: palette.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _stat(
                    'Screening match',
                    screening == null
                        ? 'Unavailable'
                        : '${_scoreNumber(screening)} / 100',
                    detail: screening != null ? 'Weighted role match' : null,
                    numeric: screening != null,
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: palette.border)),
                    ),
                    child: _stat(
                      'Application stage',
                      _statusLabel(app.status),
                      detail: app.recruiterDecision?.outcome == null
                          ? null
                          : _humanize(app.recruiterDecision!.outcome!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (rank != null) ...[
            const SizedBox(height: 10),
            Text(
              'Screening rank $rank of $candidateCount',
              textAlign: TextAlign.center,
              style: _secondary(11),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            runSpacing: 6,
            children: [
              if (data.resume case final resume?)
                OutlinedButton.icon(
                  onPressed: () => _showResume(context, resume),
                  icon: _ReportGlyph(_ReportIcon.file, color: palette.ink),
                  label: const Text('View resume'),
                ),
              _ReportPrimaryButton(
                palette: palette,
                onPressed: onDecision,
                label: 'Review decision',
                icon: _ReportIcon.arrow,
              ),
              if (candidateCount > 1) ...[
                IconButton(
                  tooltip: 'Previous candidate',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left, size: 19),
                ),
                IconButton(
                  tooltip: 'Next candidate',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right, size: 19),
                ),
              ],
              IconButton(
                tooltip: 'Refresh report',
                onPressed: onRefresh,
                icon: _ReportGlyph(
                  _ReportIcon.refresh,
                  color: onRefresh == null ? palette.muted : palette.accent,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResume(BuildContext context, ResumeDetail resume) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resume.filename case final name? when name.isNotEmpty)
              Text(name, style: _reportDisplay(16)),
            const SizedBox(height: 10),
            if (resume.isParsed) ...[
              if (resume.skills?.isNotEmpty == true)
                _SkillChips(resume.skills!),
              for (final entry in resume.experience ?? const [])
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    [entry['title'], entry['company'], entry['duration']]
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty)
                        .join(' · '),
                  ),
                ),
              if (resume.skills?.isNotEmpty != true &&
                  resume.experience?.isNotEmpty != true)
                const Text('No skills or work experience were returned.'),
            ] else
              Text(
                resume.isPending
                    ? 'Resume parsing is pending.'
                    : 'Parsed resume details are unavailable.',
              ),
          ],
        ),
        actions: [
          if (resume.fileUrl?.isNotEmpty == true) _DownloadResumeButton(resume),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value, {
    String? detail,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Column(
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: _mono(10).copyWith(color: palette.muted, letterSpacing: .6),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: numeric ? _mono(15) : _reportDisplay(15),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail, textAlign: TextAlign.center, style: _secondary(11)),
        ],
      ],
    ),
  );

  Widget _decision() {
    final decision = data.application.recruiterDecision;
    final outcome = decision?.outcome;
    final legacy = decision?.legacy == true;
    final reason = decision?.reason;
    return _panel(
      'Recruiter decision',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason != null && reason.trim().isNotEmpty
                ? reason
                : decision == null
                ? 'No recruiter decision recorded.'
                : 'No rationale recorded.',
            style: _secondary(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          _ReportPrimaryButton(
            palette: palette,
            onPressed: onReview,
            label: outcome == null
                ? 'Open decision review'
                : 'View decision review',
          ),
        ],
      ),
      key: decisionKey,
      subtitle: 'Internal review',
      status: outcome != null
          ? _status(_humanize(outcome), palette.mint)
          : _status(
              legacy ? 'Unavailable' : 'Unrecorded',
              legacy ? palette.muted : palette.amber,
            ),
    );
  }

  Widget _summary(BuildContext context, EvaluationRevision? evaluation) {
    final strengths = {
      for (final answer in evaluation?.answers ?? const <AnswerResult>[])
        ...answer.strengths,
    }.where((value) => value.trim().isNotEmpty);
    final gaps = {
      for (final answer in evaluation?.answers ?? const <AnswerResult>[])
        ...answer.gaps,
    }.where((value) => value.trim().isNotEmpty);
    final reasons =
        data.assessment?.reasons.where((value) => value.trim().isNotEmpty) ??
        const <String>[];
    final groups = [
      if (strengths.isNotEmpty) ('Strengths', strengths.toList()),
      if (gaps.isNotEmpty) ('Areas to verify', gaps.toList()),
      if (strengths.isEmpty && gaps.isEmpty && reasons.isNotEmpty)
        ('Screening findings', reasons.toList()),
    ];
    final findingCount =
        strengths.length +
        gaps.length +
        (strengths.isEmpty && gaps.isEmpty ? reasons.length : 0);
    Widget group(String label, List<String> items, {required bool preview}) {
      final strength = label == 'Strengths';
      final risk = label == 'Areas to verify';
      final tone = strength
          ? palette.goodInk
          : risk
          ? palette.amber
          : palette.accent;
      return Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: strength
                    ? palette.goodField
                    : risk
                    ? palette.warningField
                    : palette.soft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: _ReportGlyph(
                strength ? _ReportIcon.check : _ReportIcon.search,
                color: tone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  for (final item in preview ? items.take(1) : items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        item,
                        style: _secondary(),
                        maxLines: preview ? 3 : null,
                        overflow: preview ? TextOverflow.ellipsis : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _panel(
      'Assessment summary',
      groups.isEmpty
          ? Text('No assessment findings are available.', style: _secondary())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, items) in groups)
                  group(label, items, preview: true),
                OutlinedButton(
                  onPressed: () => _showReportDetails(
                    context,
                    'Assessment findings',
                    (_) => [
                      for (final (label, items) in groups)
                        group(label, items, preview: false),
                    ],
                  ),
                  child: Text('View all findings ($findingCount)'),
                ),
              ],
            ),
    );
  }

  Widget _performance(
    BuildContext context,
    List<InterviewQuestion> questions,
    Map<String, AnswerResult> answers,
  ) {
    final attempt = interview;
    final status = attempt == null
        ? null
        : attempt.status == 'DONE'
        ? 'Completed'
        : _humanize(attempt.status);
    final ready = _readyEvaluation;
    final categories = <String, List<double?>>{};
    for (final question in questions) {
      final category = question.category.trim();
      categories
          .putIfAbsent(
            category.isEmpty ? 'Other questions' : _humanize(category),
            () => [],
          )
          .add(answers[question.id]?.scoreOutOfTen);
    }
    List<Widget> categoryRatings(bool preview) => [
      for (final (index, MapEntry(key: label, value: scores))
          in (preview ? categories.entries.take(4) : categories.entries)
              .indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _rating(label, scores, switch (index) {
            0 => palette.mint,
            2 => palette.amber,
            _ => palette.blue,
          }),
        ),
    ];
    final ratings = evidenceLoading
        ? const LinearProgressIndicator(minHeight: 2)
        : evidenceError
        ? _ReportMessage(
            'Could not load interview evaluation.',
            action: TextButton(
              onPressed: onRetryEvidence,
              child: const Text('Retry'),
            ),
          )
        : questions.isEmpty
        ? Text(
            evidence?.pending == true
                ? 'Evaluation is processing.'
                : ready == null
                ? 'No published evaluation is available.'
                : 'No question ratings were returned.',
            style: _secondary(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...categoryRatings(true),
              if (categories.length > 4)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    onPressed: () => _showReportDetails(
                      context,
                      'Interview performance',
                      (_) => categoryRatings(false),
                    ),
                    child: Text('View all ${categories.length} categories'),
                  ),
                ),
            ],
          );
    final scheduledAt = attempt?.scheduledAt;
    final completedAt = attempt?.completedAt;
    return _panel(
      'Interview performance',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ratings,
          if (onManage != null || onSchedule != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                onPressed: onManage ?? onSchedule,
                child: Text(
                  onManage != null ? 'Manage schedule' : 'Schedule interview',
                ),
              ),
            ),
          ],
        ],
      ),
      key: interviewKey,
      subtitle: completedAt != null
          ? _date(context, completedAt)
          : scheduledAt != null
          ? _date(context, scheduledAt, time: true)
          : null,
      status: status == null
          ? null
          : _status(
              status,
              attempt!.status == 'DONE' ? palette.mint : palette.muted,
            ),
    );
  }

  Widget _rating(String label, List<double?> scores, Color color) {
    final rated = scores.whereType<double>().toList();
    final score = rated.isEmpty
        ? null
        : rated.reduce((sum, value) => sum + value) / rated.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              score == null ? 'Unrated' : '${_scoreNumber(score)} / 10',
              textAlign: TextAlign.end,
              style: _mono(12).copyWith(color: palette.accent),
            ),
          ],
        ),
        if (rated.length != scores.length)
          Text(
            rated.isEmpty
                ? 'No rated answers'
                : '${rated.length} of ${scores.length} rated',
            style: _secondary(11),
          ),
        if (score != null) ...[
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: (score / 10).clamp(0.0, 1.0),
            minHeight: 4,
            color: color,
            backgroundColor: palette.track,
            borderRadius: BorderRadius.circular(10),
            semanticsLabel: label,
          ),
        ],
      ],
    );
  }

  Widget _screening(BuildContext context) {
    final rows = data.assessment?.criteria ?? const <ScreeningCriterion>[];
    Widget table(
      Iterable<ScreeningCriterion> visibleRows, {
      required bool preview,
    }) => LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 480
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in visibleRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.requirement,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: preview ? 2 : null,
                          overflow: preview ? TextOverflow.ellipsis : null,
                        ),
                        _screeningStatus(row),
                        if (row.evidence.trim().isNotEmpty)
                          Text(
                            row.evidence,
                            style: _secondary(),
                            maxLines: preview ? 2 : null,
                            overflow: preview ? TextOverflow.ellipsis : null,
                          ),
                      ],
                    ),
                  ),
              ],
            )
          : _screeningTable(visibleRows, preview: preview),
    );
    return _panel(
      'Screening breakdown',
      rows.isEmpty
          ? Text(
              data.assessment?.pending == true
                  ? 'Screening is processing.'
                  : 'No screening criteria were returned.',
              style: _secondary(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                table(rows.take(4), preview: true),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    onPressed: () => _showReportDetails(
                      context,
                      'Screening breakdown',
                      (_) => [table(rows, preview: false)],
                    ),
                    child: Text('View all ${rows.length} requirements'),
                  ),
                ),
              ],
            ),
      key: screeningKey,
      subtitle: 'Resume evidence against the role requirements',
    );
  }

  Widget _screeningTable(
    Iterable<ScreeningCriterion> rows, {
    required bool preview,
  }) => Table(
    columnWidths: const {
      0: FlexColumnWidth(.29),
      1: FlexColumnWidth(.19),
      2: FlexColumnWidth(.52),
    },
    defaultVerticalAlignment: TableCellVerticalAlignment.top,
    border: TableBorder(horizontalInside: BorderSide(color: palette.border)),
    children: [
      TableRow(
        decoration: BoxDecoration(color: palette.field),
        children: [
          for (final label in ['Requirement', 'Result', 'Evidence'])
            _cell(
              label.toUpperCase(),
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.muted,
                letterSpacing: .44,
              ),
            ),
        ],
      ),
      for (final row in rows)
        TableRow(
          children: [
            _cell(
              row.requirement,
              const TextStyle(fontWeight: FontWeight.w600),
              preview: preview,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: _screeningStatus(row),
            ),
            _cell(row.evidence, _secondary(), preview: preview),
          ],
        ),
    ],
  );

  Widget _screeningStatus(ScreeningCriterion row) => _status(
    switch (row.status) {
      'PASS' => 'Matched',
      'FAIL' => 'Not matched',
      _ => _humanize(row.status),
    },
    switch (row.status) {
      'PASS' => palette.mint,
      'FAIL' => palette.amber,
      _ => palette.muted,
    },
  );

  Widget _cell(String text, TextStyle style, {bool preview = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Text(
      text,
      style: style,
      maxLines: preview ? 2 : null,
      overflow: preview ? TextOverflow.ellipsis : null,
    ),
  );

  Widget _answers(
    BuildContext context,
    List<InterviewQuestion> questions,
    Map<String, AnswerResult> answers,
  ) {
    final turns = {
      for (final turn
          in evidence?.transcript?.turns ?? const <TranscriptTurn>[])
        turn.id: turn,
    };
    return _panel(
      'Answer evidence',
      questions.isEmpty
          ? Text(
              'No published answer evidence is available.',
              style: _secondary(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (evidence?.transcriptUnavailable == true)
                  Text(
                    'The transcript revision used for this evaluation is unavailable.',
                    style: _secondary(),
                  ),
                for (final (index, question) in questions.take(4).indexed)
                  _answerTile(
                    question,
                    answers[question.id],
                    turns,
                    expanded: index == 0,
                  ),
                if (questions.length > 4)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton(
                      onPressed: () => _showReportDetails(
                        context,
                        'Answer evidence · ${questions.length} questions',
                        (_) => [
                          if (evidence?.transcriptUnavailable == true)
                            Text(
                              'The transcript revision used for this evaluation is unavailable.',
                              style: _secondary(),
                            ),
                          for (final question in questions)
                            _answerTile(question, answers[question.id], turns),
                        ],
                      ),
                      child: Text('View all ${questions.length} answers'),
                    ),
                  ),
              ],
            ),
      key: answersKey,
      subtitle: 'Interview excerpts and rubric rationale',
    );
  }

  Widget _answerTile(
    InterviewQuestion question,
    AnswerResult? answer,
    Map<String, TranscriptTurn> turns, {
    bool expanded = false,
  }) => _ReportAnswer(
    key: ValueKey((_readyEvaluation?.id, question.id)),
    palette: palette,
    question: question.text,
    rating: _answerRating(answer),
    initiallyExpanded: expanded,
    buildDetails: () => _answerDetails(question, answer, turns),
  );

  String _answerRating(AnswerResult? answer) {
    final score = answer?.scoreOutOfTen;
    return score == null
        ? (answer == null ? 'Unrated' : _humanize(answer.status))
        : '${_scoreNumber(score)} / 10';
  }

  List<Widget> _answerDetails(
    InterviewQuestion question,
    AnswerResult? answer,
    Map<String, TranscriptTurn> turns,
  ) {
    final verifiedQuotes = {
      for (final quote in answer?.evidence ?? const <EvidenceQuote>[])
        if (quote.quote.trim().isNotEmpty &&
            quote.quote.trim() != question.text.trim() &&
            turns[quote.turnId]?.text.contains(quote.quote) == true)
          quote.quote,
    };
    return [
      for (final quote in verifiedQuotes)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: palette.field,
            border: Border(left: BorderSide(color: palette.blue, width: 3)),
          ),
          child: SelectableText('“$quote”'),
        ),
      if (answer?.rationale case final rationale?
          when rationale.trim().isNotEmpty)
        SelectableText(rationale, style: _secondary())
      else
        Text('No rubric rationale was returned.', style: _secondary()),
    ];
  }

  Widget _followups(BuildContext context) {
    final evaluation = _readyEvaluation;
    final turns = <String>{
      for (final item
          in evaluation?.extraction?.questions ?? const <ExtractedAnswer>[])
        ...item.followUpTurnIds,
    };
    final questions = [
      for (final turn
          in evidence?.transcript?.turns ?? const <TranscriptTurn>[])
        if (turns.contains(turn.id) && turn.text.trim().isNotEmpty) turn.text,
    ];
    Widget row(int index, String question, {required bool preview}) =>
        Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: palette.field,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: _mono(
                    10,
                  ).copyWith(color: palette.accent, height: 1.85),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  maxLines: preview ? 3 : null,
                  overflow: preview ? TextOverflow.ellipsis : null,
                ),
              ),
            ],
          ),
        );
    return _panel(
      'Follow-up questions',
      questions.isEmpty
          ? Text(
              evidence?.transcriptUnavailable == true
                  ? 'The evaluation transcript is unavailable.'
                  : 'No verified interview follow-ups are available.',
              style: _secondary(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, question) in questions.take(2).indexed)
                  row(index, question, preview: true),
                OutlinedButton(
                  onPressed: () => _showReportDetails(
                    context,
                    'Follow-up questions',
                    (_) => [
                      for (final (index, question) in questions.indexed)
                        row(index, question, preview: false),
                    ],
                  ),
                  child: Text('View all ${questions.length} follow-ups'),
                ),
              ],
            ),
    );
  }

  TextStyle _secondary([double size = 13]) =>
      TextStyle(fontSize: size, color: palette.muted);

  Widget _status(String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          text,
          style: _secondary(12).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

const _workspaceGap = 14.0;

Future<void> _showReportDetails(
  BuildContext context,
  String title,
  List<Widget> Function(BuildContext) buildContent,
) => showDialog<void>(
  context: context,
  builder: (context) {
    final palette = _ReportPalette(context.isDarkTheme);
    return Dialog(
      backgroundColor: palette.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: palette.border),
      ),
      constraints: const BoxConstraints(maxWidth: 720),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: _reportDisplay(19)),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close details',
                ),
              ],
            ),
            Divider(color: palette.border),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buildContent(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
TextStyle _mono(double size) => TextStyle(
  fontFamily: 'JetBrains Mono',
  fontSize: size,
  fontWeight: FontWeight.w600,
);
String _scoreNumber(double score) =>
    score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1);

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    super.key,
    required this.palette,
    required this.child,
    this.title,
    this.subtitle,
    this.status,
    this.profile = false,
  });

  final _ReportPalette palette;
  final Widget child;
  final String? title, subtitle;
  final Widget? status;
  final bool profile;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final compact = MediaQuery.sizeOf(context).width <= 480;
    final horizontal = compact ? 12.0 : 17.0;
    final profilePadding = MediaQuery.sizeOf(context).width <= 760
        ? 18.0
        : 23.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: radius,
        border: Border.all(color: palette.border),
        boxShadow: palette.dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1026334d),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          textStyle: DefaultTextStyle.of(context).style,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile)
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        palette.blue,
                        const Color(0xff7c7af5),
                        Colors.transparent,
                      ],
                      stops: const [0, .30, .65, 1],
                    ),
                  ),
                ),
              if (title case final heading?)
                Container(
                  padding: EdgeInsets.fromLTRB(horizontal, 13, horizontal, 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                heading,
                                style: _reportDisplay(
                                  16,
                                ).copyWith(letterSpacing: -.24),
                              ),
                            ),
                            if (subtitle case final detail?) ...[
                              const SizedBox(height: 3),
                              Text(
                                detail,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (status case final badge?) ...[
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: badge,
                        ),
                      ],
                    ],
                  ),
                ),
              Padding(
                padding: profile
                    ? EdgeInsets.fromLTRB(
                        profilePadding,
                        profilePadding - 2,
                        profilePadding,
                        profilePadding,
                      )
                    : EdgeInsets.fromLTRB(
                        horizontal,
                        13,
                        horizontal,
                        compact ? 12 : 16,
                      ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterviewScore extends StatelessWidget {
  const _InterviewScore({required this.palette, required this.score});

  final _ReportPalette palette;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final value = score;
    return Stack(
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.paper,
            boxShadow: value == null
                ? null
                : [
                    BoxShadow(
                      color: palette.mint.withValues(alpha: .18),
                      blurRadius: 23,
                      spreadRadius: -5,
                    ),
                  ],
          ),
          child: SizedBox.square(
            dimension: 146,
            child: CircularProgressIndicator(
              value: value == null ? 0 : (value / 100).clamp(0.0, 1.0),
              strokeWidth: 9,
              strokeAlign: CircularProgressIndicator.strokeAlignInside,
              trackGap: 0,
              strokeCap: StrokeCap.butt,
              color: palette.mint,
              backgroundColor: palette.track,
              semanticsLabel: value == null
                  ? 'Interview score unavailable'
                  : 'Interview score',
            ),
          ),
        ),
        if (value == null)
          Icon(Icons.bar_chart_rounded, color: palette.muted, size: 32)
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _scoreNumber(value),
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.2),
                style: _mono(42).copyWith(
                  height: 1.08,
                  letterSpacing: -2.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'OUT OF 100',
                style: _mono(
                  10,
                ).copyWith(color: palette.muted, letterSpacing: .6),
              ),
            ],
          ),
      ],
    );
  }
}

class _ReportPrimaryButton extends StatelessWidget {
  const _ReportPrimaryButton({
    required this.palette,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final _ReportPalette palette;
  final String label;
  final VoidCallback onPressed;
  final _ReportIcon? icon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.primary,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.blue.withValues(alpha: .40),
            blurRadius: 22,
            spreadRadius: -9,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shadowColor: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label)),
            if (icon case final glyph?) ...[
              const SizedBox(width: 6),
              _ReportGlyph(glyph, color: Colors.white, size: 13),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportAnswer extends StatefulWidget {
  const _ReportAnswer({
    super.key,
    required this.palette,
    required this.question,
    required this.rating,
    required this.initiallyExpanded,
    required this.buildDetails,
  });

  final _ReportPalette palette;
  final String question, rating;
  final bool initiallyExpanded;
  final List<Widget> Function() buildDetails;

  @override
  State<_ReportAnswer> createState() => _ReportAnswerState();
}

class _ReportAnswerState extends State<_ReportAnswer> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RotatedBox(
                      quarterTurns: _expanded ? 0 : 3,
                      child: _ReportGlyph(
                        _ReportIcon.chevron,
                        color: palette.accent,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.question,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      widget.rating,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.buildDetails(),
              ),
            ),
        ],
      ),
    );
  }
}
