part of 'question_preparation_panel.dart';

const _questionCategories = [
  ('TECHNICAL', 'Technical', ScreeningStyle.accent),
  ('BEHAVIORAL', 'Behavioral', ScreeningStyle.navy),
  ('SITUATIONAL', 'Situational', ScreeningStyle.green),
];

Text _questionText(
  BuildContext context,
  String value, {
  AppType type = AppType.caption,
  Color color = ScreeningStyle.muted,
}) => Text(value, style: ScreeningStyle.text(context, type, color: color));

extension _CompactQuestions on _QuestionPreparationPanelState {
  Widget _compactQuestions(
    String state,
    String statusMessage,
    List<dynamic> questions,
    bool approved,
    bool frozen,
    bool canChange,
  ) {
    final draftReady = const {'READY', 'FALLBACK'}.contains(state);
    final editableTime =
        _retryAt == null || !DateTime.now().isBefore(_retryAt!);
    final canRecover = !_busy && !_stale && !_reviewRequired && editableTime;
    final margin = ScreeningStyle.inset(context);
    final width = MediaQuery.sizeOf(context).width;
    final notices = _draftNotices(questions, canChange);
    final hasNotice =
        notices.isNotEmpty || _error != null || _busy || !draftReady;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (questions.isEmpty && !_busy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 26),
            child: Column(
              children: [
                Text(
                  'No questions in this draft',
                  style: ScreeningStyle.title(context, AppType.h4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  canChange
                      ? 'Add a question to start preparing the interview.'
                      : statusMessage,
                  style: ScreeningStyle.text(
                    context,
                    AppType.bodySm,
                    color: ScreeningStyle.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final (index, raw) in questions.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _compactQuestionRow(
            Map<String, dynamic>.from(raw as Map),
            index,
            questions.length,
            canChange && !frozen,
          ),
        ],
      ],
    );
    final coverage = _coverage(questions);
    final note = frozen
        ? 'This question set is locked to preserve the interview record.'
        : approved
        ? 'This revision is approved. Changing a question requires approval again.'
        : 'Review the wording and order, then approve this revision to continue scheduling.';
    final readyToSchedule =
        approved &&
        !_stale &&
        !_reviewRequired &&
        _unsavedAdd == null &&
        _data != null &&
        QuestionSet.fromJson(_data!).schedulable;
    return ScreeningPanel(
      child: DefaultTextStyle(
        style: ScreeningStyle.text(context, AppType.caption),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreeningHeading(
              'Interview questions',
              'Review the question set before sending an invitation.',
              action: ScreeningButton(
                'Add question',
                onPressed: canChange && questions.length < 100
                    ? _addQuestion
                    : null,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(margin, 0, margin, 12),
              child: Wrap(
                spacing: 18,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ScreeningStyle.tint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: _questionText(
                      context,
                      frozen
                          ? 'Locked · interview scheduled'
                          : approved
                          ? 'Approved for scheduling'
                          : 'Draft for review',
                      color: ScreeningStyle.blue,
                      type: AppType.bodySm,
                    ),
                  ),
                  _questionText(context, '${questions.length} questions'),
                  if (_data?['revision'] case final revision?)
                    _questionText(context, 'Revision $revision'),
                ],
              ),
            ),
            if (hasNotice)
              Padding(
                padding: EdgeInsets.fromLTRB(margin, 0, margin, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_busy)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: ScreeningStyle.accent,
                      ),
                    if (!draftReady && questions.isNotEmpty)
                      _questionText(context, statusMessage),
                    ...notices,
                    if (_error case final error?)
                      _questionText(context, error, color: ScreeningStyle.red),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(margin, 0, margin, 6),
              child: width > 900
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: list),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: width <= 1100 ? 220 : 260,
                          child: coverage,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [list, const SizedBox(height: 14), coverage],
                    ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: ScreeningStyle.line),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin, vertical: 12),
              child: LayoutBuilder(
                builder: (context, size) {
                  final actions = Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ScreeningButton(
                        'Refresh draft',
                        kind: ScreeningButtonKind.link,
                        onPressed: _busy ? null : _refresh,
                      ),
                      if (state == 'NOT_REQUESTED' &&
                          _application?.canPrepareQuestions == true)
                        ScreeningButton(
                          'Prepare questions',
                          kind: ScreeningButtonKind.primary,
                          onPressed: _busy || _reviewRequired ? null : _prepare,
                        ),
                      if (!approved &&
                          !frozen &&
                          (draftReady || state == 'FAILED'))
                        ScreeningButton(
                          'Regenerate draft',
                          kind: ScreeningButtonKind.link,
                          onPressed: canRecover ? _regenerate : null,
                        ),
                      if (!approved && !frozen && state == 'FAILED')
                        ScreeningButton(
                          'Retry generation',
                          onPressed: canRecover
                              ? () => _command('retry')
                              : null,
                        ),
                      if (draftReady && !frozen && !approved)
                        ScreeningButton(
                          'Approve question set',
                          kind: ScreeningButtonKind.primary,
                          onPressed:
                              canChange &&
                                  questions.isNotEmpty &&
                                  _unsavedAdd == null
                              ? () => _command('approve')
                              : null,
                        ),
                      if (approved && !frozen)
                        ScreeningButton(
                          'Continue to scheduling',
                          kind: ScreeningButtonKind.primary,
                          onPressed:
                              !_busy &&
                                  readyToSchedule &&
                                  (_application?.eligibleForInterview ?? true)
                              ? widget.onSchedule
                              : null,
                        ),
                    ],
                  );
                  final caption = _questionText(context, note);
                  return size.maxWidth >= 660 &&
                          MediaQuery.textScalerOf(context).scale(12) <= 16
                      ? Row(
                          children: [
                            Expanded(child: caption),
                            const SizedBox(width: 12),
                            actions,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            caption,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverage(List<dynamic> questions) {
    final counts = <String, int>{};
    for (final question in questions) {
      final category = (question as Map)['category']?.toString() ?? '';
      counts.update(category, (value) => value + 1, ifAbsent: () => 1);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScreeningStyle.soft,
        border: Border.all(color: ScreeningStyle.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _questionText(
            context,
            'Interview coverage',
            color: ScreeningStyle.ink,
            type: AppType.caption,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: ScreeningStyle.line),
          const SizedBox(height: 12),
          if (_questionCategories.any(
            (category) => counts.containsKey(category.$1),
          )) ...[
            SizedBox(
              height: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (key, _, color) in _questionCategories)
                    if (counts[key] case final count?)
                      Expanded(
                        flex: count,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 13),
          ],
          for (final (key, label, color) in _questionCategories) ...[
            Row(
              children: [
                _dot(color),
                const SizedBox(width: 8),
                Expanded(
                  child: _questionText(
                    context,
                    label,
                    color: ScreeningStyle.ink,
                    type: AppType.caption,
                  ),
                ),
                _questionText(
                  context,
                  '${counts[key] ?? 0}',
                  color: ScreeningStyle.ink,
                  type: AppType.caption,
                ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 9),
          Text(
            'Use questions that reflect this role’s requirements. Review technical depth, clarity, and coverage before approval.',
            style: ScreeningStyle.text(
              context,
              AppType.caption,
              color: ScreeningStyle.muted,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _dot(Color color) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _compactQuestionRow(
    Map<String, dynamic> question,
    int index,
    int count,
    bool enabled,
  ) {
    final category = question['category']?.toString() ?? '';
    final type = _questionCategories
        .where((item) => item.$1 == category)
        .firstOrNull;
    final source = (question['source']?.toString() ?? '')
        .toLowerCase()
        .replaceAll('_', ' ');
    final number = index + 1;
    final id = question['id'] as String;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(type?.$3 ?? ScreeningStyle.muted),
                const SizedBox(width: 7),
                _questionText(
                  context,
                  type?.$2 ?? category,
                  color: ScreeningStyle.ink,
                  type: AppType.caption,
                ),
              ],
            ),
            if (source.isNotEmpty)
              _questionText(
                context,
                source[0].toUpperCase() + source.substring(1),
                type: AppType.caption,
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${question['text']}',
          style: ScreeningStyle.text(context, AppType.caption),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _compactIcon(
          ScreeningGlyph.edit,
          'Edit question $number',
          enabled ? () => _editQuestion(question) : null,
        ),
        const SizedBox(width: 2),
        _compactIcon(
          ScreeningGlyph.delete,
          'Remove question $number',
          enabled ? () => _command('remove', {'id': id}) : null,
        ),
        const SizedBox(width: 2),
        _compactIcon(
          ScreeningGlyph.up,
          'Move question $number up',
          enabled && index > 0 ? () => _move(id, -1) : null,
        ),
        const SizedBox(width: 2),
        _compactIcon(
          ScreeningGlyph.down,
          'Move question $number down',
          enabled && number < count ? () => _move(id, 1) : null,
        ),
      ],
    );
    return Container(
      key: ValueKey('question-$id'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ScreeningStyle.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final inline =
              MediaQuery.sizeOf(context).width > 640 && bounds.maxWidth >= 350;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ScreeningStyle.tint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _questionText(
                      context,
                      number.toString().padLeft(2, '0'),
                      color: ScreeningStyle.blue,
                      type: AppType.bodySm,
                    ),
                  ),
                ),
              ),
              SizedBox(width: inline ? 12 : 10),
              Expanded(
                child: inline
                    ? copy
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [copy, const SizedBox(height: 10), actions],
                      ),
              ),
              if (inline) ...[const SizedBox(width: 12), actions],
            ],
          );
        },
      ),
    );
  }

  Widget _compactIcon(
    ScreeningGlyph glyph,
    String label,
    VoidCallback? action,
  ) => IconButton(
    tooltip: label,
    onPressed: action,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(28),
      fixedSize: const Size.square(28),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      hoverColor: glyph == ScreeningGlyph.delete
          ? ScreeningStyle.rose
          : ScreeningStyle.tint,
    ),
    icon: ScreeningIcon(
      glyph,
      size: 14,
      color: action == null
          ? ScreeningStyle.muted.withValues(alpha: .5)
          : ScreeningStyle.muted,
    ),
  );
}

extension _CompactQuestionEditor on _AddQuestionDialogState {
  Widget _compactEditor(BuildContext context) {
    final adding = widget.initial == null;
    return ScreeningDialog(
      title: adding ? 'Add interview question' : 'Edit interview question',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _questionText(
              context,
              'Question type',
              color: ScreeningStyle.ink,
              type: AppType.caption,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              style: ScreeningStyle.text(context, AppType.caption),
              decoration: ScreeningStyle.field(context),
              items: [
                for (final (key, label, _) in _questionCategories)
                  DropdownMenuItem(value: key, child: Text(label)),
              ],
              onChanged: (value) {
                if (value != null) _category = value;
              },
            ),
            const SizedBox(height: 10),
            _questionText(
              context,
              'Question',
              color: ScreeningStyle.ink,
              type: AppType.caption,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _text,
              minLines: 5,
              maxLines: 5,
              maxLength: 10000,
              style: ScreeningStyle.text(context, AppType.body),
              decoration: ScreeningStyle.field(context),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a question.'
                  : null,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                ScreeningButton(
                  'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
                ScreeningButton(
                  adding ? 'Add question' : 'Save changes',
                  kind: ScreeningButtonKind.primary,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      Navigator.pop(context, {
                        'text': _text.text.trim(),
                        'category': _category,
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
