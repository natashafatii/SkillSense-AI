import 'package:flutter/material.dart';
import '../../models/application.dart';
import '../../models/recruitment_evidence.dart';
import '../../services/recruitment_review_controller.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../widgets/recruiter_top_bar.dart';

String percent(double? value, {bool ratio = false}) => value == null
    ? 'Unavailable'
    : '${(value * (ratio ? 100 : 1)).toStringAsFixed(1)}%';
String localTime(DateTime? value) => value == null
    ? 'Unavailable'
    : '${value.toLocal()} (${DateTime.now().timeZoneName})';

class RecruitmentReviewScreen extends StatefulWidget {
  const RecruitmentReviewScreen({
    super.key,
    required this.applicationId,
    this.interviewId,
    this.service,
  });
  final String applicationId;
  final String? interviewId;
  final RecruitmentWorkflowService? service;
  @override
  State<RecruitmentReviewScreen> createState() =>
      _RecruitmentReviewScreenState();
}

class _RecruitmentReviewScreenState extends State<RecruitmentReviewScreen> {
  late final RecruitmentReviewController controller;
  final reason = TextEditingController(),
      overrideReason = TextEditingController();
  String? transcriptId, compareTranscriptId, evaluationId, compareEvaluationId;
  DateTime? scheduledAt;
  @override
  void initState() {
    super.initState();
    controller = RecruitmentReviewController(
      widget.applicationId,
      interviewId: widget.interviewId,
      service: widget.service,
      isVisible: () => mounted && ModalRoute.of(context)?.isCurrent == true,
    );
    controller.addListener(_changed);
    controller.refresh();
  }

  void _changed() {
    if (controller.review == null && controller.error == 'Session changed.') {
      reason.clear();
      overrideReason.clear();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    reason.dispose();
    overrideReason.dispose();
    super.dispose();
  }

  Widget section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget line(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: SelectableText(text),
  );
  Widget button(String text, VoidCallback action, {bool enabled = true}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: OutlinedButton(
          onPressed: enabled && controller.canCommand ? action : null,
          child: Text(text),
        ),
      );
  Future<bool> confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(detail)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> decision(String outcome, {bool override = false}) async {
    final r = controller.review!;
    if (reason.text.trim().isEmpty ||
        (override && overrideReason.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the reason and, for an early override, a separate override justification.',
          ),
        ),
      );
      return;
    }
    final accepted = await confirm(
      override
          ? 'Early decision override: $outcome'
          : 'Record $outcome decision',
      '${r.application.candidateName ?? r.application.candidateEmail}\nApplication version ${r.application.version}\n'
      'Current outcome: ${r.decision?.outcome ?? 'None'}\nLatest evaluation: ${r.latestEvaluation?.revision.value ?? 'Unavailable'} (${r.latestEvaluation?.id ?? 'Unavailable'})\n'
      '${override ? 'You are deliberately overriding normal evidence readiness.\nJustification: ${overrideReason.text}\n' : ''}Reason: ${reason.text}',
    );
    if (!accepted || !mounted) return;
    await controller.command((captured) async {
      await controller.service.decide(
        captured,
        outcome,
        reason.text,
        overrideReason: override ? overrideReason.text : null,
      );
    }, reviewed: r);
  }

  Future<void> chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> recover(bool reopen) async {
    final reviewed = controller.review!;
    if (scheduledAt == null) {
      await chooseTime();
      return;
    }
    if (!await confirm(
      reopen ? 'Schedule another attempt' : 'Reschedule this interview',
      'Time: ${localTime(scheduledAt)}\nReason: ${reason.text}\n'
      '${reopen ? 'A new interview identity and frozen question copies will be created. Historical evidence is retained.' : 'This interview keeps its current identity.'}',
    )) {
      return;
    }
    await controller.command((r) async {
      final next = await controller.service.recover(
        r,
        scheduledAt!,
        reason.text,
        reopen: reopen,
      );
      controller.interviewId = next.id;
    }, reviewed: reviewed);
    if (mounted && reopen && controller.error == null) {
      // Replacing the route discards any state bound to the previous attempt.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecruitmentReviewScreen(
            applicationId: widget.applicationId,
            interviewId: controller.interviewId,
          ),
        ),
      );
    }
  }

  void showTurn(TranscriptRevision? transcript, String id) {
    final turn = transcript?.turns.where((t) => t.id == id).firstOrNull;
    if (turn == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Frozen turn ${turn.id}'),
        content: SingleChildScrollView(
          child: SelectableText(
            '${turn.role}\n${turn.text}'
            '${turn.start == null ? '' : '\nStart: ${turn.start}s'}${turn.end == null ? '' : '\nEnd: ${turn.end}s'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget turnLink(TranscriptRevision? t, String id, {String? quote}) {
    final exists = t?.turns.any((turn) => turn.id == id) == true;
    return TextButton(
      onPressed: exists ? () => showTurn(t, id) : null,
      child: Text(
        '${quote == null ? id : '“$quote” — $id'}${exists ? '' : ' (frozen turn unavailable)'}',
      ),
    );
  }

  Widget transcriptView(TranscriptRevision t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      line(
        'Revision ${t.number} · ${t.source} · ${localTime(t.createdAt)}\nHash ${t.hash}',
      ),
      if (t.turns.isEmpty) line(t.text),
      for (final turn in t.turns)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: SelectableText('${turn.role}: ${turn.text}'),
          subtitle: Text(
            '${turn.id}${turn.start == null ? '' : ' · ${turn.start}s'}${turn.end == null ? '' : ' – ${turn.end}s'}',
          ),
        ),
    ],
  );
  Widget scores(RecruitmentReview r) {
    final s = controller.currentScore;
    return section('Server scores', [
      const Text(
        'Current application score uses the latest attempt. Historical attempt evidence is shown separately below.',
      ),
      line('Status: ${s?.status ?? 'Unavailable / refreshing'}'),
      line(
        'Screening match: ${percent(s?.match ?? (r.application.screening?.status == 'SUCCEEDED' ? r.application.screening?.matchScore : null))}\nInterview performance: ${percent(s?.interview)}\nCombined recommendation: ${percent(s?.publishedCombined)}',
      ),
      if (s != null) ...[
        line(
          'Weighted coverage: ${percent(s.coverage, ratio: true)} · Answer coverage: ${percent(s.answerCoverage, ratio: true)}',
        ),
        line(
          'Policy ${s.policyVersion ?? 'Unavailable'} · Score revision ${s.revision ?? 'Unavailable'} (${s.id ?? 'Unavailable'})\nRubric ${s.rubric ?? 'Unavailable'} version ${s.rubricVersion ?? 'Unavailable'}',
        ),
        line(
          'Assessment ${s.assessmentId ?? 'Unavailable'} revision ${s.assessmentRevision ?? 'Unavailable'}\nEvaluation ${s.evaluationId ?? 'Unavailable'} revision ${s.evaluationRevision ?? 'Unavailable'}',
        ),
        line(
          'Server weights: ${s.weights}\nBreakdown: ${s.breakdown}\nCompleted: ${localTime(s.completedAt)}\n${s.explanation}\n${s.error}',
        ),
      ],
      const Text(
        'Behavioral observations are reviewed separately and do not establish answer quality or evaluation completion.',
      ),
      ExpansionTile(
        title: const Text('Immutable score history (up to 100)'),
        children: [
          for (final h in r.scores.history)
            ListTile(
              title: Text(
                'Revision ${h.number} · ${h.status} · ${percent(h.status == 'COMPLETE' ? h.score : null)}',
              ),
              subtitle: SelectableText(
                'Match ${percent(h.match)} · Interview ${percent(h.interview)} · Coverage ${percent(h.coverage, ratio: true)}\n${localTime(h.createdAt)} · ${h.error}\nSource inputs: ${h.inputs}',
              ),
            ),
        ],
      ),
    ]);
  }

  Widget transcripts(RecruitmentReview r) {
    final h = r.transcripts!;
    final selected = transcriptId == null
        ? (h.revisions.where((t) => t.id == h.selected).firstOrNull ??
              h.revisions.firstOrNull)
        : h.revisions.where((t) => t.id == transcriptId).firstOrNull;
    final comparison = h.revisions
        .where((t) => t.id == compareTranscriptId)
        .firstOrNull;
    return section('Transcript revisions', [
      line(
        'Selected: ${h.selected ?? 'None'} · Selection version ${h.version?.value ?? 'Unavailable'} · ${h.pinned ? 'Pinned' : 'Not pinned'}',
      ),
      const Text(
        'History contains the newest 100 revisions. Evaluations continue to cite their frozen transcript.',
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('transcript-${r.interview!.id}-${selected?.id}'),
        initialValue: selected?.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Inspect revision'),
        items: [
          for (final t in h.revisions)
            DropdownMenuItem(
              value: t.id,
              child: Text(
                'Revision ${t.number} · ${t.source}${t.id == h.selected ? ' · Selected' : ''}',
              ),
            ),
        ],
        onChanged: (id) => setState(() {
          transcriptId = id;
        }),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'transcript-comparison-${r.interview!.id}-${comparison?.id}',
        ),
        initialValue: comparison?.id ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Compare with revision'),
        items: [
          const DropdownMenuItem(value: '', child: Text('No comparison')),
          for (final t in h.revisions)
            DropdownMenuItem(
              value: t.id,
              child: Text('Revision ${t.number} · ${t.source}'),
            ),
        ],
        onChanged: (id) => setState(() {
          compareTranscriptId = id;
        }),
      ),
      if (transcriptId != null && selected == null)
        const Text(
          'Your selected transcript is outside the available history window. Review and select a revision before submitting; no newer transcript has been substituted.',
        ),
      if (selected != null)
        ExpansionTile(
          title: const Text('Revision text and turns'),
          children: [transcriptView(selected)],
        ),
      if (comparison != null)
        ExpansionTile(
          title: Text('Comparison revision ${comparison.number}'),
          children: [transcriptView(comparison)],
        ),
      button(
        'Select this transcript and reevaluate',
        () async {
          if (await confirm(
            'Change pinned transcript?',
            'Revision ${selected!.number}\nReason: ${reason.text}\nA new evaluation will be requested. Released reports remain historical.',
          )) {
            await controller.command((captured) async {
              await controller.service.selectTranscript(
                captured,
                selected.id,
                reason.text,
              );
            }, reviewed: r);
          }
        },
        enabled:
            selected != null &&
            selected.text.trim().isNotEmpty &&
            selected.turns.isNotEmpty &&
            h.version != null &&
            r.interview?.status == 'DONE' &&
            r.interview?.completedAt != null &&
            const {
              'USABLE',
              'INSUFFICIENT_EVIDENCE',
            }.contains(r.interview?.completionOutcome),
      ),
    ]);
  }

  Widget evaluationView(RecruitmentReview r, EvaluationRevision e) {
    final t = e.frozenTranscript(r.transcripts!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(
          'Evaluation ${e.revision.value} · ${e.status} · ${e.id}\nScore ${percent(e.score)} · Coverage ${percent(e.coverage, ratio: true)}\nContract ${e.contract} · Model ${e.model} · Run ${e.runNumber ?? 'Unavailable'}\nPublished ${localTime(e.publishedAt)} · Attempts ${e.attempts} · Next retry ${localTime(e.nextAttemptAt)}\nSupersedes ${e.supersedes ?? 'None'} · Feedback released ${e.feedbackReleased}\n${e.error}',
        ),
        line(
          'Frozen transcript ${e.transcriptNumber ?? 'Unavailable'} · Hash ${e.transcriptHash}\nContext hash ${e.contextHash}',
        ),
        if (t == null)
          const Text(
            'The frozen transcript is unavailable in this history window. Evidence links are disabled.',
          ),
        for (final a in e.answers)
          ExpansionTile(
            title: Text(
              '${r.interview!.questions.where((q) => q.id == a.questionId).firstOrNull?.text ?? 'Frozen question ${a.questionId} (unavailable)'} · ${a.status}',
            ),
            children: [
              line(
                'Frozen question ID ${a.questionId}\nCriteria: ${a.criteria}\nUncertainty: ${percent(a.uncertainty, ratio: true)}\n${a.rationale}\nStrengths: ${a.strengths.join('; ')}\nGaps: ${a.gaps.join('; ')}',
              ),
              for (final evidence in a.evidence)
                turnLink(t, evidence.turnId, quote: evidence.quote),
            ],
          ),
        if (e.extraction == null)
          const Text(
            'No extraction record (historical answers-v1 is supported).',
          ),
        if (e.extraction != null) ...[
          for (final a in e.extraction!.questions)
            ExpansionTile(
              title: Text('Extraction ${a.questionId} · ${a.state}'),
              children: [
                line(
                  'Confidence ${percent(a.confidence, ratio: true)} · Attribution ${a.method}',
                ),
                if (a.askedTurnId != null) turnLink(t, a.askedTurnId!),
                line('Answer turns'),
                for (final id in a.answerTurnIds) turnLink(t, id),
                line('Follow-up turns'),
                for (final id in a.followUpTurnIds) turnLink(t, id),
                for (final span in a.spans) ...[
                  line(
                    'Span ${span.start}–${span.end}${span.startSeconds == null ? '' : ' · Start ${span.startSeconds}s'}${span.endSeconds == null ? '' : ' · End ${span.endSeconds}s'}',
                  ),
                  turnLink(
                    t,
                    span.turnId,
                    quote: t == null
                        ? null
                        : t.turns
                                  .where((turn) => turn.id == span.turnId)
                                  .firstOrNull ==
                              null
                        ? null
                        : span.textIn(
                            t.turns.firstWhere(
                              (turn) => turn.id == span.turnId,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          line('Unmatched transcript turns'),
          for (final id in e.extraction!.unmatchedTurnIds) turnLink(t, id),
        ],
        if (t != null)
          ExpansionTile(
            title: const Text('Evaluation’s frozen transcript'),
            children: [transcriptView(t)],
          ),
      ],
    );
  }

  Widget evaluations(RecruitmentReview r) {
    final h = r.evaluations!;
    final selected = evaluationId == null
        ? h.revisions.firstOrNull
        : h.revisions.where((e) => e.id == evaluationId).firstOrNull;
    final comparison = h.revisions
        .where((e) => e.id == compareEvaluationId)
        .firstOrNull;
    return section('Evaluation and extraction review', [
      line(
        'Transcript ${h.transcriptState} · ${h.selectedSource}\n${h.reason}\nDeadline ${localTime(h.deadline)}',
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('evaluation-${r.interview!.id}-${selected?.id}'),
        initialValue: selected?.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Evaluation revision'),
        items: [
          for (final e in h.revisions)
            DropdownMenuItem(
              value: e.id,
              child: Text('Revision ${e.revision.value} · ${e.status}'),
            ),
        ],
        onChanged: (id) => setState(() {
          evaluationId = id;
        }),
      ),
      if (evaluationId != null && selected == null)
        const Text(
          'Your selected evaluation is outside the available history window. Select a revision to inspect it.',
        ),
      if (selected != null) evaluationView(r, selected),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'evaluation-comparison-${r.interview!.id}-${comparison?.id}',
        ),
        initialValue: comparison?.id ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Compare evaluation'),
        items: [
          const DropdownMenuItem(value: '', child: Text('No comparison')),
          for (final e in h.revisions)
            DropdownMenuItem(
              value: e.id,
              child: Text('Revision ${e.revision.value} · ${e.status}'),
            ),
        ],
        onChanged: (id) => setState(() {
          compareEvaluationId = id;
        }),
      ),
      if (comparison != null)
        ExpansionTile(
          title: Text('Comparison: evaluation ${comparison.revision.value}'),
          children: [evaluationView(r, comparison)],
        ),
      button(
        'Request evaluation rerun',
        () async {
          if (await confirm(
            'Rerun latest evaluation?',
            'Revision ${r.latestEvaluation?.revision.value}\nReason: ${reason.text}\nCurrent score will be invalidated while new evidence is processed.',
          )) {
            await controller.command((captured) async {
              await controller.service.rerun(captured, reason.text);
            }, reviewed: r);
          }
        },
        enabled:
            r.interview?.status == 'DONE' &&
            r.interview?.completedAt != null &&
            r.interview?.completionOutcome == 'USABLE' &&
            r.latestEvaluation?.terminal == true,
      ),
    ]);
  }

  Widget decisions(RecruitmentReview r) {
    final finalStage = {
      ApplicationStatus.decision,
      ApplicationStatus.rejected,
      ApplicationStatus.unknown,
    }.contains(r.application.status);
    final canReopen =
        r.latestAttempt &&
        r.interview?.status == 'DONE' &&
        r.interview?.completedAt != null &&
        r.interview!.questions.any((question) => question.isApproved) &&
        !finalStage;
    final d = r.decision;
    final currentAttemptReviewed = r.interview == null || r.latestAttempt;
    return section('Decisions and interview recovery', [
      if (!currentAttemptReviewed)
        const Text(
          'Select the latest attempt to review its current evidence before recording or reversing a decision.',
        ),
      line(
        'Current outcome: ${d?.legacy == true ? 'Legacy — unrecorded decision' : d?.outcome ?? 'None'}\nActor: ${d?.actor ?? 'Unavailable'} · ${localTime(d?.createdAt)}\nEvaluation: ${d?.evaluation ?? 'Unavailable'}\nReason: ${d?.reason ?? ''}${d?.override == true ? '\nOverride: ${d?.overrideReason}' : ''}',
      ),
      Wrap(
        children: [
          button(
            'HIRE',
            () => decision('HIRE'),
            enabled: r.normalDecisionReady && d == null && !finalStage,
          ),
          button(
            'REJECT',
            () => decision('REJECT'),
            enabled: r.normalDecisionReady && d == null && !finalStage,
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Deliberate early override'),
        children: [
          const Text(
            'Use only when deliberately deciding before normal evidence readiness. A separate justification is required.',
          ),
          TextField(
            key: const Key('decision-override-reason'),
            controller: overrideReason,
            maxLength: 2000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Override justification',
            ),
          ),
          Wrap(
            children: [
              button(
                'Override: HIRE',
                () => decision('HIRE', override: true),
                enabled: currentAttemptReviewed && d == null && !finalStage,
              ),
              button(
                'Override: REJECT',
                () => decision('REJECT', override: true),
                enabled: currentAttemptReviewed && d == null && !finalStage,
              ),
            ],
          ),
        ],
      ),
      button(
        'Reverse recorded decision',
        () async {
          if (await confirm(
            'Reverse current decision?',
            'Outcome ${d?.outcome ?? 'Legacy / unavailable'}\nDecision evaluation ${d?.evaluation ?? 'Unavailable'} (revision ${r.evaluations?.revisions.where((e) => e.id == d?.evaluation).firstOrNull?.revision.value ?? 'Unavailable'})\nCurrent evaluation revision ${r.latestEvaluation?.revision.value ?? 'Unavailable'}\nApplication version ${r.application.version}\nReason: ${reason.text}\nThis does not record a replacement decision.',
          )) {
            await controller.command((captured) async {
              await controller.service.reverse(captured, reason.text);
            }, reviewed: r);
          }
        },
        enabled:
            currentAttemptReviewed &&
            r.application.status == ApplicationStatus.decision,
      ),
      TextButton(
        onPressed: controller.busy ? null : chooseTime,
        child: Text(
          scheduledAt == null
              ? 'Choose future interview time'
              : localTime(scheduledAt),
        ),
      ),
      Wrap(
        children: [
          button(
            'Reschedule',
            () => recover(false),
            enabled:
                r.latestAttempt &&
                r.interview?.status == 'SCHEDULED' &&
                r.interview?.workflowState == 'SCHEDULED' &&
                !finalStage,
          ),
          button(
            'Schedule another attempt',
            () => recover(true),
            enabled: canReopen,
          ),
        ],
      ),
      const Text(
        'Eligibility and lifecycle changes are validated by the server. Rescheduling retains identity; another attempt receives a new identity and preserves historical evidence.',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final r = controller.review;
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fc),
      appBar: AppBar(
        title: const Text('Recruiter evidence and decisions'),
        actions: [
          IconButton(
            onPressed: controller.busy || controller.loading
                ? null
                : () => controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const RecruiterTopBar(pageTitle: 'Evidence review'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (controller.loading || controller.busy)
                  const LinearProgressIndicator(),
                if (controller.error != null)
                  section('Review required', [line(controller.error!)]),
                if (controller.requiresReview)
                  section('Unsaved input retained', [
                    const Text(
                      'Refresh, compare the current versions with your intended command, then explicitly accept the reviewed state. No command has been automatically retried.',
                    ),
                    TextButton(
                      onPressed: controller.loading || controller.busy
                          ? null
                          : () => controller.refresh(poll: false),
                      child: const Text('Refresh current state'),
                    ),
                    TextButton(
                      onPressed: controller.error == null && !controller.loading
                          ? controller.confirmRefreshedReview
                          : null,
                      child: const Text('I reviewed the current versions'),
                    ),
                  ]),
                if (controller.retryAt != null)
                  line(
                    'Retry permitted after ${localTime(controller.retryAt)}',
                  ),
                if (r != null) ...[
                  section('Application and attempts', [
                    line(
                      '${r.application.candidateName ?? r.application.candidateEmail} · ${r.application.jobTitle}\nStage ${r.application.rawStatus} · Version ${r.application.version}',
                    ),
                    if (r.attempts.isEmpty)
                      const Text(
                        'No interview attempt. An early override requires deliberate confirmation.',
                      ),
                    if (r.interview != null) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(r.interview!.id),
                        initialValue: r.interview!.id,
                        isExpanded: true,
                        items: [
                          for (final attempt in r.attempts)
                            DropdownMenuItem(
                              value: attempt.id,
                              child: Text(
                                '${attempt.id} · ${attempt.workflowState}${attempt.id == r.attempts.first.id ? ' · Latest' : ' · Historical'}',
                              ),
                            ),
                        ],
                        onChanged: controller.busy
                            ? null
                            : (id) {
                                if (id != null) {
                                  setState(() {
                                    transcriptId = null;
                                    compareTranscriptId = null;
                                    evaluationId = null;
                                    compareEvaluationId = null;
                                  });
                                  controller.selectAttempt(id);
                                }
                              },
                      ),
                      line(
                        'Workflow ${r.interview!.workflowState} · Completion ${r.interview!.completionOutcome} · Evaluation ${r.interview!.evaluationStatus}\nScheduled ${localTime(r.interview!.scheduledAt)} · Completed ${localTime(r.interview!.completedAt)}',
                      ),
                    ],
                  ]),
                  section('Command reason', [
                    const Text(
                      'This text is preserved across refreshes and conflicts. Each command uses the versions currently shown.',
                    ),
                    TextField(
                      key: const Key('workflow-command-reason'),
                      controller: reason,
                      maxLength: 2000,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Reason for the intended command',
                      ),
                    ),
                  ]),
                  scores(r),
                  if (r.transcripts != null) transcripts(r),
                  if (r.evaluations != null) evaluations(r),
                  decisions(r),
                  section('Feedback report history', [
                    const Text(
                      'Released reports retain their original evidence identity. These are independent of behavioral analysis reports.',
                    ),
                    for (final f in r.feedback)
                      line(
                        'Revision ${f.revision.value} · ${f.status} · Edit version ${f.editVersion.value}\nEvaluation ${f.evaluation ?? 'Unavailable'} · ${f.contract}\nPrepared ${localTime(f.preparedAt)} · Released ${localTime(f.releasedAt)} · Retracted ${localTime(f.retractedAt)}\nHash ${f.hash}\n${f.error ?? ''}',
                      ),
                  ]),
                  section('Private workflow history (newest 100)', [
                    for (final a in r.actions)
                      line(
                        '${a.action} · ${localTime(a.createdAt)}\nActor ${a.actorId ?? 'Unavailable'} · Expected version ${a.expectedVersion ?? 'Unavailable'} · Interview ${a.interviewId ?? 'None'}\n${a.reason}\n${a.details}',
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
