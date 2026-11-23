part of 'recruitment_review_screen.dart';

// Reference dimensions are logical pixels. Columns collapse before their
// contents become cramped; evidence and commands keep their original sources.
extension _InterviewReviewPages on _RecruitmentReviewScreenState {
  Widget _overviewPage(RecruitmentReview r, double? height) => LayoutBuilder(
    builder: (context, bounds) {
      final filled = height != null && bounds.maxWidth >= 690;
      final available = filled ? height.clamp(640.0, double.infinity) : null;
      final topHeight = available == null ? null : available * 5 / 11;
      final bottomHeight = available == null ? null : available * 6 / 11;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _columns(
            _recommendation(r, height: topHeight),
            _checklist(r, height: topHeight),
            leftFlex: 2,
            rightFlex: 1,
          ),
          _questionTypes(r, height: bottomHeight),
        ],
      );
    },
  );
  Widget _columns(
    Widget left,
    Widget right, {
    int leftFlex = 3,
    int rightFlex = 2,
  }) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth < (leftFlex == 1 && rightFlex == 1 ? 480 : 690)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 14),
          Expanded(flex: rightFlex, child: right),
        ],
      );
    },
  );

  Widget _inspection(String title, Widget child) => _expansion(
    storageId: 'inspection-$title',
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    title: Text(title, style: AppType.h4.style(context)),
    children: [child],
  );

  Widget _evaluationPage(RecruitmentReview r, double? height) {
    final revisions = r.evaluations?.revisions ?? const <EvaluationRevision>[];
    final selected = evaluationId == null
        ? revisions.firstOrNull
        : revisions.where((e) => e.id == evaluationId).firstOrNull;
    final comparison = revisions
        .where((e) => e.id == compareEvaluationId)
        .firstOrNull;
    Widget picker(String label, String? value, bool compare) => SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value-${r.interview?.id}'),
        initialValue: value ?? (compare ? '' : null),
        style: AppType.caption.style(
          context,
          color: context.themeForeground(const Color(0xFF16213A)),
        ),
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (compare)
            const DropdownMenuItem(value: '', child: Text('No comparison')),
          for (final e in revisions)
            DropdownMenuItem(
              value: e.id,
              child: Text(
                'Revision ${e.revision.value} · ${e.status}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) => _update(() {
          if (compare) {
            compareEvaluationId = id;
          } else {
            evaluationId = id;
          }
        }),
      ),
    );
    final toolbar = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.themeSurface(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.themeOutline(const Color(0xFFE2E8F2)),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Evaluation', style: AppType.h4.style(context)),
          picker('Revision', selected?.id, false),
          picker('Compare', comparison?.id, true),
          _pill('Score ${percent(selected?.score)}', const Color(0xFF3D4A63)),
          _pill(
            'Coverage ${percent(selected?.coverage, ratio: true)}',
            const Color(0xFF3D4A63),
          ),
          OutlinedButton.icon(
            onPressed:
                controller.canCommand &&
                    r.latestAttempt &&
                    r.interview?.status == 'DONE' &&
                    r.interview?.completedAt != null &&
                    r.interview?.completionOutcome == 'USABLE' &&
                    r.latestEvaluation?.terminal == true
                ? () => _rerunEvaluation(r)
                : null,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Request rerun'),
          ),
        ],
      ),
    );
    final paneHeight = height == null
        ? null
        : (height - 80).clamp(540.0, double.infinity);
    final answers = _reviewCard(
      'Answers and extracted evidence',
      height: paneHeight,
      badge: Text(
        '${selected?.answers.length ?? 0} questions',
        style: AppType.caption.style(context),
      ),
      children: [
        if (selected == null)
          const Text(
            'No evaluation available. Select a revision to inspect it.',
          ),
        if (selected != null && selected.answers.isEmpty)
          Text(
            selected.error.isEmpty
                ? 'No scored answers available.'
                : selected.error,
          ),
        if (selected != null)
          for (final answer in selected.answers)
            _answerEvidence(r, selected, answer),
        if (r.evaluations != null)
          _inspection(
            'Evaluation source and processing',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(
                  'Transcript ${r.evaluations!.transcriptState} · ${r.evaluations!.selectedSource}',
                ),
                line(r.evaluations!.reason),
                line('Deadline ${localTime(r.evaluations!.deadline)}'),
              ],
            ),
          ),
        if (selected != null && r.transcripts != null)
          _inspection(
            'Evaluation details and frozen evidence',
            evaluationView(r, selected),
          ),
        if (comparison != null && r.transcripts != null)
          _inspection(
            'Comparison · revision ${comparison.revision.value}',
            evaluationView(r, comparison),
          ),
      ],
    );
    final transcript = selected != null && r.transcripts != null
        ? selected.frozenTranscript(r.transcripts!)
        : null;
    final extraction = selected?.extraction;
    final linked = <String>{
      for (final answer in extraction?.questions ?? <ExtractedAnswer>[]) ...[
        if (answer.askedTurnId != null) answer.askedTurnId!,
        ...answer.answerTurnIds,
        ...answer.followUpTurnIds,
        ...answer.spans.map((span) => span.turnId),
      ],
    };
    final unmatched = transcript?.turns
        .where(
          (turn) =>
              !linked.contains(turn.id) ||
              (extraction?.unmatchedTurnIds.contains(turn.id) ?? false),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        _columns(
          answers,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _reviewCard(
                'Transcript coverage',
                height: paneHeight == null ? null : paneHeight / 2,
                badge: transcript != null && unmatched != null
                    ? _pill(
                        '${transcript.turns.length - unmatched} of ${transcript.turns.length} linked',
                        _reviewAmber,
                      )
                    : null,
                children: [
                  if (selected != null && r.transcripts != null)
                    _coverageMap(r, selected)
                  else
                    const Text('Transcript coverage map unavailable.'),
                ],
              ),
              if (r.transcripts != null)
                _transcriptCard(
                  r,
                  height: paneHeight == null ? null : paneHeight / 2,
                )
              else
                _reviewCard(
                  'Transcript version',
                  height: height,
                  children: [const Text('No transcript available.')],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _answerEvidence(
    RecruitmentReview r,
    EvaluationRevision evaluation,
    AnswerResult answer,
  ) {
    final questions = evaluation.questions.isNotEmpty
        ? evaluation.questions
        : r.interview?.questions ?? <InterviewQuestion>[];
    final question = questions
        .where((q) => q.id == answer.questionId)
        .firstOrNull;
    final transcript = r.transcripts == null
        ? null
        : evaluation.frozenTranscript(r.transcripts!);
    final color = reviewAnswerScoreColor(answer.scoreOutOfTen);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.themeOutline(const Color(0xFFE2E8F2)),
        ),
      ),
      child: _expansion(
        storageId: 'answer-${evaluation.id}-${answer.questionId}',
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: ReviewQuestionBadge(category: question?.category ?? ''),
        title: Text(
          question?.text ?? 'Frozen question ${answer.questionId}',
          style: AppType.caption.style(context),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${answer.scoreOutOfTen?.toStringAsFixed(1) ?? '—'}/10',
              style: AppType.numeric.style(
                context,
                color: context.themeForeground(color),
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (MediaQuery.sizeOf(context).width > 600)
              _pill(_displayStatus(answer.status), _reviewTeal),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _columns(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow('Answer excerpt'),
                const SizedBox(height: 7),
                if (answer.evidence.isEmpty)
                  const Text('No excerpt available.'),
                for (final quote in answer.evidence)
                  turnLink(transcript, quote.turnId, quote: quote.quote),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow('Extracted evidence'),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final text in [...answer.strengths, ...answer.gaps])
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.themeSurface(const Color(0xFFEEF2F8)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          text,
                          style: AppType.caption.style(context),
                        ),
                      ),
                  ],
                ),
                if (answer.rationale.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(answer.rationale),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transcriptCard(RecruitmentReview r, {double? height}) => _reviewCard(
    'Transcript version',
    height: height,
    badge: _pill('In use', _reviewBlue),
    children: [
      Text(
        'Scores are based on the frozen transcript. Pick another version if it looks wrong.',
        style: AppType.caption.style(context),
      ),
      // Retains selection, comparison, pinning and version-aware reevaluation.
      const SizedBox(height: 14),
      transcripts(r, embedded: true),
    ],
  );

  Widget _feedbackPage(RecruitmentReview r, double? height) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noticeBackground = isDark
        ? const Color(0xFF172640)
        : const Color(0xFFEAF0FF);
    final noticeForeground = isDark
        ? const Color(0xFFB8CCFF)
        : const Color(0xFF264AA8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: noticeBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2B4165)
                  : const Color(0xFFD8E4FF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 17, color: noticeForeground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The report already sent to the candidate stays as it is. New drafts do not replace it unless you release them.',
                  style: AppType.caption.style(
                    context,
                    color: noticeForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        _columns(
          FeedbackReviewPanel(
            key: ValueKey('feedback-${r.application.id}-${r.interview?.id}'),
            controller: controller,
            availableHeight: height == null ? null : height - 56,
          ),
          _reviewCard(
            'Feedback history',
            height: height == null ? null : height - 56,
            children: [
              if (r.interview case final interview?)
                InterviewReplayPanel(
                  key: ValueKey(interview.id),
                  interviewId: interview.id,
                ),
              if (r.feedback.isEmpty) const Text('No feedback prepared.'),
              for (final report in r.feedback) ...[
                if (report.retractedAt != null)
                  _timeline(
                    'Report withdrawn from candidate',
                    _scheduleTime(report.retractedAt),
                    'Version ${report.revision.value} · Private reason recorded',
                    _reviewAmber,
                  ),
                if (report.releasedAt != null)
                  _timeline(
                    'Report sent to candidate',
                    _scheduleTime(report.releasedAt),
                    'Version ${report.revision.value}',
                    _reviewTeal,
                  ),
                _timeline(
                  report.error?.isNotEmpty == true
                      ? 'Feedback could not be prepared'
                      : 'Feedback prepared',
                  _scheduleTime(report.preparedAt),
                  'Version ${report.revision.value} · ${_displayStatus(report.status)}',
                  report.error?.isNotEmpty == true ? _reviewRed : _reviewBlue,
                ),
              ],
            ],
          ),
          leftFlex: 13,
          rightFlex: 10,
        ),
      ],
    );
  }

  Widget _timeline(
    String title,
    String time,
    String detail,
    Color color, {
    String? source,
  }) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: context.themeOutline(const Color(0xFFE2E8F2)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (source != null) _pill(source, color),
                    Text(
                      time,
                      style: AppType.caption.style(
                        context,
                        color: TypographyColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(title, style: AppType.h4.style(context)),
                const SizedBox(height: 3),
                Text(detail, style: AppType.caption.style(context)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _keyValues(List<(String, String)> rows) => Column(
    children: [
      for (final (index, row) in rows.indexed)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : Border(
                    top: BorderSide(
                      color: context.themeOutline(const Color(0xFFEDF1F7)),
                    ),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.$1,
                  style: AppType.caption.style(
                    context,
                    color: TypographyColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  row.$2,
                  style: AppType.caption.style(context),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _historyPage(RecruitmentReview r, double? height) {
    final score = r.latestAttempt ? controller.currentScore : null;
    final evaluation = r.latestEvaluation;
    final report =
        r.feedback.where((report) => report.releasedAt != null).firstOrNull ??
        r.feedback.firstOrNull;
    final cardHeight = height == null ? null : height / 2;
    final events = r.actions.where(
      (event) =>
          _historyFilter == 'all' ||
          (_historyFilter == 'workflow'
              ? !event.action.startsWith('feedback') &&
                    !event.action.startsWith('evaluation')
              : event.action.startsWith(_historyFilter)),
    );
    final summaries = [
      _reviewCard(
        'How the score is calculated',
        height: cardHeight,
        children: [
          _keyValues([
            ('Screening', percent(score?.match)),
            ('Interview', percent(score?.interview)),
            (
              'Behavioral',
              score?.weights['behavioral'] == 0
                  ? 'Excluded by policy'
                  : percent(score?.weights['behavioral'], ratio: true),
            ),
            ('Combined score', percent(score?.publishedCombined)),
            ('Calculated', _scheduleTime(score?.completedAt)),
          ]),
          if (score != null && score.status != 'COMPLETE')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                score.error == 'EVALUATION_UNAVAILABLE'
                    ? 'Combined scoring requires a complete evaluation. ${evaluation?.assessedCount ?? 0} of ${evaluation?.questionCount ?? 0} questions assessed.'
                    : score.explanation,
                style: AppType.caption.style(context),
              ),
            ),
          _inspection(
            'Score policy and source inputs',
            Column(children: [_contribution(r), scores(r)]),
          ),
        ],
      ),
      _reviewCard(
        'Evaluation summary',
        height: cardHeight,
        children: [
          _keyValues([
            ('Status', _displayStatus(evaluation?.status ?? 'Unavailable')),
            ('Reviewed by', 'AI-assisted review'),
            (
              'Questions assessed',
              '${evaluation?.assessedCount ?? 0} of ${evaluation?.questionCount ?? 0}',
            ),
            ('Coverage', percent(evaluation?.coverage, ratio: true)),
            ('Completed', _scheduleTime(evaluation?.publishedAt)),
          ]),
        ],
      ),
      _reviewCard(
        'Candidate feedback',
        height: cardHeight,
        children: [
          _keyValues([
            (
              'Status',
              report == null
                  ? 'Not prepared'
                  : report.retractedAt != null
                  ? 'Withdrawn'
                  : report.releasedAt != null
                  ? 'Sent to candidate'
                  : report.status == 'READY'
                  ? 'Ready to release'
                  : _displayStatus(report.status),
            ),
            (
              'Sent',
              report?.releasedAt == null
                  ? 'Not sent'
                  : _scheduleTime(report?.releasedAt),
            ),
            ('Earlier drafts', '${r.feedback.skip(1).length}'),
            (
              'Candidate view',
              report?.releasedAt != null && report?.retractedAt == null
                  ? 'Visible in app'
                  : 'Not released',
            ),
          ]),
        ],
      ),
      _reviewCard(
        'Score history',
        height: cardHeight,
        badge: Text('Past evaluations', style: AppType.caption.style(context)),
        children: [
          if (r.scores.history.isEmpty)
            const Text('No score history available.'),
          for (final item in r.scores.history)
            _keyValues([
              ('Version ${item.number}', item.status),
              ('Screening', percent(item.match)),
              ('Interview', percent(item.interview)),
              ('Total', percent(item.status == 'COMPLETE' ? item.score : null)),
            ]),
          const SizedBox(height: 14),
          Text(
            'Earlier scores are kept for reference and never edited.',
            style: AppType.caption.style(context),
          ),
        ],
      ),
    ];
    return _columns(
      _reviewCard(
        'Activity history',
        height: height,
        badge: Wrap(
          spacing: 2,
          children: [
            for (final filter in [
              ('all', 'All'),
              ('workflow', 'Interview'),
              ('evaluation', 'Eval'),
              ('feedback', 'Feedback'),
            ])
              InkWell(
                onTap: () => _update(() => _historyFilter = filter.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _historyFilter == filter.$1
                        ? context.themeSurface(const Color(0xFFEEF2F8))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(filter.$2, style: AppType.caption.style(context)),
                ),
              ),
          ],
        ),
        children: [
          if (events.isEmpty) const Text('No workflow events recorded.'),
          for (final event in events)
            _timeline(
              _displayStatus(event.action.replaceAll('.', '_')),
              _scheduleTime(event.createdAt),
              '${event.reason}${event.details.isEmpty ? '' : '\n${event.details}'}',
              event.action.startsWith('feedback')
                  ? _reviewTeal
                  : event.action.startsWith('evaluation')
                  ? _reviewBlue
                  : _reviewAmber,
              source: event.action.split('.').first,
            ),
        ],
      ),
      LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth >= 520
            ? Column(
                children: [
                  _columns(
                    summaries[0],
                    summaries[1],
                    leftFlex: 1,
                    rightFlex: 1,
                  ),
                  _columns(
                    summaries[2],
                    summaries[3],
                    leftFlex: 1,
                    rightFlex: 1,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: summaries,
              ),
      ),
      leftFlex: 10,
      rightFlex: 15,
    );
  }
}
