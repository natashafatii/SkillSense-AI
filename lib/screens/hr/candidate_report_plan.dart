part of 'candidate_report_screen.dart';

typedef _PlanQuestion = ({String text, String category, String source});

class _DraftPlan extends StatelessWidget {
  const _DraftPlan({
    super.key,
    required this.application,
    required this.focusAreas,
  });
  final Application application;
  final List<String> focusAreas;

  @override
  Widget build(BuildContext context) => QuestionPreparationPanel(
    applicationId: application.id,
    application: application,
    onApprovalChanged: (_, _) {},
    previewBuilder:
        (
          context, {
          required draft,
          required error,
          required busy,
          required refresh,
          required edit,
          required regenerate,
        }) {
          final status = draft?.generationStatus;
          final note = switch (status) {
            'NOT_REQUESTED' => 'No interview questions have been prepared yet.',
            'QUEUED' ||
            'GENERATING' => 'Interview questions are being generated.',
            'FAILED' =>
              'Question generation failed. Open the editor to review recovery options.',
            'FALLBACK' =>
              'Template questions are available for recruiter review.',
            'READY' when draft?.frozenAt != null =>
              'This question set is locked.',
            'READY' when draft?.approvedAt != null =>
              'The draft is approved for scheduling.',
            'READY' => 'Review and approve the draft before scheduling.',
            _ =>
              busy
                  ? 'Loading interview questions…'
                  : 'Question preparation is unavailable.',
          };
          return _InterviewPlan(
            questions: [
              for (final question in draft?.questions ?? [])
                (
                  text: question.text,
                  category: question.category,
                  source: question.source,
                ),
            ],
            note: error ?? note,
            focusAreas: focusAreas,
            loading: busy,
            actions: [
              if (edit != null)
                OutlinedButton(
                  onPressed: edit,
                  child: Text(
                    status == 'NOT_REQUESTED'
                        ? 'Prepare questions'
                        : 'Edit questions',
                  ),
                ),
              if (regenerate != null)
                OutlinedButton(
                  onPressed: regenerate,
                  child: const Text('Regenerate'),
                ),
              if (error != null || status == 'QUEUED' || status == 'GENERATING')
                TextButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('Refresh questions'),
                ),
            ],
          );
        },
  );
}

class _ScheduledPlan extends StatelessWidget {
  const _ScheduledPlan({required this.interview, required this.focusAreas});
  final RecruiterInterview interview;
  final List<String> focusAreas;

  @override
  Widget build(BuildContext context) => _InterviewPlan(
    questions: [
      for (final question in interview.questions)
        (
          text: question.text,
          category: question.category,
          source: question.source,
        ),
    ],
    date: interview.scheduledAt,
    focusAreas: focusAreas,
    note: interview.questions.isEmpty
        ? 'No questions were returned for this interview.'
        : 'Showing the questions saved for this interview.',
  );
}

class _InterviewPlan extends StatelessWidget {
  const _InterviewPlan({
    required this.questions,
    required this.note,
    this.date,
    this.focusAreas = const [],
    this.loading = false,
    this.actions = const [],
  });
  final List<_PlanQuestion> questions;
  final String note;
  final DateTime? date;
  final List<String> focusAreas;
  final bool loading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final count = questions.length;
    final day = date;
    final detail =
        '$count ${count == 1 ? 'question' : 'questions'}'
        '${day == null ? '' : ' · ${_date(context, day)}'}';
    return _ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _SectionHeading(
                'Interview plan',
                detail: count == 0 ? null : detail,
              ),
              if (actions.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (focusAreas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Focus areas from screening', style: _labelStyle(context)),
            const SizedBox(height: 6),
            _SkillChips(focusAreas, color: _warning, outline: true),
          ],
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => _ReportColumns(
                width: constraints.maxWidth,
                columns: constraints.maxWidth >= 865 ? 3 : 2,
                gap: 12,
                children: [
                  for (var index = 0; index < questions.length; index++)
                    _QuestionTile(
                      number: index + 1,
                      question: questions[index],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(note, style: _mutedStyle(context)),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.number, required this.question});
  final int number;
  final _PlanQuestion question;

  @override
  Widget build(BuildContext context) => _InsetCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tag('$number', color: _accent, pill: false),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (question.category.isNotEmpty)
                    _Tag(_humanize(question.category), color: _accent),
                  if (question.source.isNotEmpty)
                    _Tag(_humanize(question.source)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
