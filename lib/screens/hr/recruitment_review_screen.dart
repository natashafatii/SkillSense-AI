import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../models/interview_analysis_contract.dart';
import '../../models/application.dart';
import '../../models/interview.dart';
import '../../models/recruitment_evidence.dart';
import '../../services/recruitment_review_controller.dart';
import '../../services/recruitment_workflow_service.dart';
import '../../widgets/recruiter_top_bar.dart';
import '../../widgets/interview_review_top_bar.dart';
import '../../widgets/feedback_review_panel.dart';
import '../../widgets/recruiter_interview_dashboard.dart';

part 'interview_review_pages.dart';

const _reviewBlue = Color(0xFF3E6FF0);
const _reviewTeal = Color(0xFF0E8F76);
const _reviewRed = Color(0xFFC8374D);
const _reviewAmber = Color(0xFFD9892B);

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
    this.showInterviewDashboard = false,
  });
  final String applicationId;
  final String? interviewId;
  final RecruitmentWorkflowService? service;
  final bool showInterviewDashboard;
  @override
  State<RecruitmentReviewScreen> createState() =>
      _RecruitmentReviewScreenState();
}

class _RecruitmentReviewScreenState extends State<RecruitmentReviewScreen> {
  late final RecruitmentReviewController controller;
  final reason = TextEditingController(),
      decisionReason = TextEditingController(),
      overrideReason = TextEditingController();
  String? transcriptId, compareTranscriptId, evaluationId, compareEvaluationId;
  DateTime? scheduledAt;
  int _dashboardRefresh = 0;
  int _tab = 0;
  String _historyFilter = 'all';
  CancelToken? _checklistRequest;
  String? _checklistAttempt;
  RecruiterReportResult? _checklistReport;
  bool _checklistLoading = false;

  Future<void> _loadChecklist(String? id, {bool refresh = false}) async {
    if (!refresh && _checklistAttempt == id) return;
    _checklistRequest?.cancel();
    _checklistAttempt = id;
    final token = _checklistRequest = CancelToken();
    setState(() {
      _checklistReport = null;
      _checklistLoading = id != null;
    });
    if (id == null) return;
    try {
      final recording = await controller.service.interviewRecording(
        id,
        cancelToken: token,
      );
      if (token.isCancelled || recording.sessionId == null) return;
      final report = await controller.service.interviewBehavior(
        InterviewSessionIdentity(
          interviewId: id,
          sessionId: recording.sessionId!,
        ),
        cancelToken: token,
      );
      if (mounted && !token.isCancelled) {
        setState(() => _checklistReport = report);
      }
    } catch (_) {
      // Missing or inaccessible behavioral data is shown as unavailable.
    } finally {
      if (mounted && !token.isCancelled) {
        setState(() => _checklistLoading = false);
      }
    }
  }

  static const _tabs = [
    'Overview',
    'Evidence',
    'Evaluation',
    'Feedback',
    'History',
  ];

  void _refresh() {
    setState(() => _dashboardRefresh++);
    controller.refresh();
    _loadChecklist(controller.review?.interview?.id, refresh: true);
  }

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
      decisionReason.clear();
      overrideReason.clear();
    }
    if (mounted) {
      _loadChecklist(controller.review?.interview?.id);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _checklistRequest?.cancel();
    controller.removeListener(_changed);
    controller.dispose();
    reason.dispose();
    decisionReason.dispose();
    overrideReason.dispose();
    super.dispose();
  }

  void _update(VoidCallback action) => setState(action);
  Widget section(String title, List<Widget> children) =>
      _reviewCard(title, children: children);
  // Expansion state is a bool, while descendant scroll positions are doubles.
  // Give each tile its own entry and a separate namespace for its content.
  Widget _expansion({
    required String storageId,
    required Widget title,
    required List<Widget> children,
    EdgeInsetsGeometry? tilePadding,
    EdgeInsetsGeometry? childrenPadding,
    ShapeBorder? shape,
    ShapeBorder? collapsedShape,
    Widget? leading,
    Widget? trailing,
  }) => ExpansionTile(
    key: PageStorageKey(
      'review-expansion-${controller.review?.interview?.id}-$storageId',
    ),
    title: title,
    tilePadding: tilePadding,
    childrenPadding: childrenPadding,
    shape: shape,
    collapsedShape: collapsedShape,
    leading: leading,
    trailing: trailing,
    children: [
      Column(
        key: const PageStorageKey('expansion-content'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ],
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
  Future<bool> confirm(
    String title,
    String detail, {
    TextEditingController? input,
    TextEditingController? justification,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 520),
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(detail),
                if (input != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: input,
                    maxLength: 2000,
                    minLines: 4,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFFBFCFE),
                      labelText: 'Reason (required)',
                    ),
                  ),
                ],
                if (justification != null)
                  TextField(
                    controller: justification,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Override justification (required)',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([input, justification]),
              builder: (_, _) => FilledButton(
                onPressed:
                    (input?.text.trim().isEmpty ?? false) ||
                        (justification?.text.trim().isEmpty ?? false)
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> decision(
    String outcome, {
    bool override = false,
    RecruitmentReview? reviewed,
  }) async {
    final r = reviewed ?? controller.review!;

    final accepted = await confirm(
      override
          ? 'Early decision override: $outcome'
          : 'Record $outcome decision',
      '${r.application.candidateName ?? r.application.candidateEmail}\nApplication version ${r.application.version}\n'
      'Current outcome: ${r.decision?.outcome ?? 'None'}\nLatest evaluation: ${r.latestEvaluation?.revision.value ?? 'Unavailable'} (${r.latestEvaluation?.id ?? 'Unavailable'})',
      input: decisionReason,
      justification: override ? overrideReason : null,
    );
    if (!accepted || !mounted) return;
    await controller.command((captured) async {
      await controller.service.decide(
        captured,
        outcome,
        decisionReason.text.trim(),
        overrideReason: override ? overrideReason.text.trim() : null,
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
    scheduledAt = null;
    await chooseTime();
    final time = scheduledAt;
    if (!mounted || time == null) return;
    if (!await confirm(
      reopen ? 'Schedule another attempt' : 'Reschedule this interview',
      'Time: ${localTime(scheduledAt)}\nReason: ${reason.text}\n'
      '${reopen ? 'A new interview identity and frozen question copies will be created. Historical evidence is retained.' : 'This interview keeps its current identity.'}',
      input: reason,
    )) {
      return;
    }
    await controller.command((r) async {
      final next = await controller.service.recover(
        r,
        time,
        reason.text.trim(),
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
            service: widget.service,
            showInterviewDashboard: widget.showInterviewDashboard,
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
          'Server weights: ${s.weights}\nBreakdown: ${s.breakdown}\nCompleted: ${localTime(s.completedAt)}\n${s.explanation}\n${s.blockers.isNotEmpty ? s.blockers.join('\n') : s.error}',
        ),
      ],
      const Text(
        'Behavioral observations are reviewed separately and do not establish answer quality or evaluation completion.',
      ),
      _expansion(
        storageId: 'score-history',
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

  Widget transcripts(RecruitmentReview r, {bool embedded = false}) {
    final h = r.transcripts!;
    final selected = transcriptId == null
        ? (h.revisions.where((t) => t.id == h.selected).firstOrNull ??
              h.revisions.firstOrNull)
        : h.revisions.where((t) => t.id == transcriptId).firstOrNull;
    final comparison = h.revisions
        .where((t) => t.id == compareTranscriptId)
        .firstOrNull;
    final children = <Widget>[
      if (!embedded)
        line(
          'Selected: ${h.selected ?? 'None'} · Selection version ${h.version?.value ?? 'Unavailable'} · ${h.pinned ? 'Pinned' : 'Not pinned'}',
        ),
      if (!embedded)
        const Text(
          'History contains the newest 100 revisions. Evaluations continue to cite their frozen transcript.',
        ),
      DropdownButtonFormField<String>(
        key: ValueKey('transcript-${r.interview!.id}-${selected?.id}'),
        initialValue: selected?.id,
        isExpanded: true,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: context.themeForeground(const Color(0xFF16213A)),
        ),
        decoration: const InputDecoration(labelText: 'View version'),
        items: [
          for (final t in h.revisions)
            DropdownMenuItem(
              value: t.id,
              child: Text(
                'Revision ${t.number} · ${t.source}${t.id == h.selected ? ' · Selected' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) => setState(() {
          transcriptId = id;
        }),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'transcript-comparison-${r.interview!.id}-${comparison?.id}',
        ),
        initialValue: comparison?.id ?? '',
        isExpanded: true,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: context.themeForeground(const Color(0xFF16213A)),
        ),
        decoration: const InputDecoration(labelText: 'Compare with'),
        items: [
          const DropdownMenuItem(value: '', child: Text('No comparison')),
          for (final t in h.revisions)
            DropdownMenuItem(
              value: t.id,
              child: Text(
                'Revision ${t.number} · ${t.source}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
        _expansion(
          storageId: 'transcript-${selected.id}',
          title: const Text(
            'Read transcript',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          children: [transcriptView(selected)],
        ),
      if (comparison != null)
        _expansion(
          storageId: 'transcript-comparison-${comparison.id}',
          title: Text('Comparison revision ${comparison.number}'),
          children: [transcriptView(comparison)],
        ),
      button(
        'Use this transcript and re-evaluate',
        () async {
          if (await confirm(
            'Change pinned transcript?',
            'Revision ${selected!.number}\nA new evaluation will be requested. Released reports remain historical.',
            input: reason,
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
    ];
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, bounds) => bounds.maxWidth >= 300
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 10),
                      Expanded(child: children[2]),
                    ],
                  )
                : Column(children: children.take(3).toList()),
          ),
          ...children.skip(3),
        ],
      );
    }
    return section('Transcript revisions', children);
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
          _expansion(
            storageId: 'evaluation-${e.id}-answer-${a.questionId}',
            title: Text(
              '${r.interview!.questions.where((q) => q.id == a.questionId).firstOrNull?.text ?? 'Frozen question ${a.questionId} (unavailable)'} · ${a.status}',
            ),
            children: [
              line(
                'Frozen question ID ${a.questionId}\nCriteria: ${a.criteria}\nUncertainty: ${percent(a.uncertainty, ratio: true)}\n${a.rationale}\nStrengths: ${a.strengths.join('; ')}\nGaps: ${a.gaps.join('; ')}',
              ),
              _cardGrid([
                section('Answer excerpt', [
                  if (a.evidence.isEmpty) const Text('No excerpt available.'),
                  for (final evidence in a.evidence)
                    turnLink(t, evidence.turnId, quote: evidence.quote),
                ]),
                section('Extracted evidence', [
                  for (final extracted
                      in e.extraction?.questions.where(
                            (item) => item.questionId == a.questionId,
                          ) ??
                          const <ExtractedAnswer>[])
                    line(
                      '${extracted.state} · ${percent(extracted.confidence, ratio: true)} confidence',
                    ),
                  if (a.strengths.isNotEmpty) line(a.strengths.join('\n')),
                  if (a.gaps.isNotEmpty) line(a.gaps.join('\n')),
                  if (e.extraction == null)
                    const Text('No extraction available.'),
                ]),
              ]),
            ],
          ),
        if (e.extraction == null)
          const Text(
            'No extraction record (historical answers-v1 is supported).',
          ),
        if (e.extraction != null) ...[
          for (final a in e.extraction!.questions)
            _expansion(
              storageId: 'evaluation-${e.id}-extraction-${a.questionId}',
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
          _expansion(
            storageId: 'evaluation-${e.id}-frozen-transcript',
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
      if (selected != null) _coverageMap(r, selected),
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
        _expansion(
          storageId: 'evaluation-comparison-${comparison.id}',
          title: Text('Comparison: evaluation ${comparison.revision.value}'),
          children: [evaluationView(r, comparison)],
        ),
    ]);
  }

  Widget decisions(RecruitmentReview r, {double? height}) {
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
    final metrics = _metrics(r);
    final weights = r.latestAttempt ? controller.currentScore?.weights : null;
    final currentAttemptReviewed = r.interview == null || r.latestAttempt;
    final enabled =
        controller.canCommand && r.normalDecisionReady && !finalStage;
    return _reviewCard(
      'Decision',
      height: height,
      badge: _pill(
        d == null
            ? 'PENDING'
            : d.legacy
            ? 'UNRECORDED'
            : 'RECORDED',
        d == null
            ? _reviewAmber
            : d.outcome == 'REJECT'
            ? _reviewRed
            : _reviewTeal,
      ),
      children: [
        if (!currentAttemptReviewed)
          const Text(
            'Select the latest attempt to record or reverse a decision.',
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.themeSurface(
              d == null
                  ? const Color(0xFFF7F9FD)
                  : d.outcome == 'HIRE'
                  ? const Color(0xFFE4F5F0)
                  : const Color(0xFFFCEEF0),
            ),
            border: Border.all(
              color: context.themeOutline(
                d == null
                    ? const Color(0xFFE2E8F2)
                    : d.outcome == 'HIRE'
                    ? const Color(0xFFC5E7DE)
                    : const Color(0xFFF1CCD2),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d == null)
                const Text(
                  'No decision yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        d.outcome == 'HIRE' ? Icons.check : Icons.close,
                        size: 16,
                        color: d.outcome == 'HIRE'
                            ? const Color(0xFF067A63)
                            : const Color(0xFFA52F43),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      d.outcome ?? 'Unrecorded',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.4,
                        color: context.themeForeground(
                          d.outcome == 'HIRE'
                              ? const Color(0xFF067A63)
                              : const Color(0xFFA52F43),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 7),
              Text(
                d == null
                    ? 'Review the evidence, then record Hire or Reject with a reason.'
                    : [
                        if (d.reason != null) '“${d.reason}”',
                        'Recorded ${_scheduleTime(d.createdAt)}',
                        if (d.override) d.overrideReason,
                      ].whereType<String>().join('\n'),
              ),
            ],
          ),
        ),
        if (d == null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _reviewTeal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: enabled ? () => decision('HIRE') : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Hire'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _reviewRed,
                    side: const BorderSide(color: Color(0xFFF1CCD2)),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: enabled ? () => decision('REJECT') : null,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
        ...[
          if (currentAttemptReviewed &&
              r.application.status == ApplicationStatus.decision)
            button(
              'Reverse recorded decision',
              () async {
                if (await confirm(
                  'Reverse current decision?',
                  'Outcome ${d?.outcome ?? 'Legacy / unavailable'}\nDecision evaluation ${d?.evaluation ?? 'Unavailable'} (revision ${r.evaluations?.revisions.where((e) => e.id == d?.evaluation).firstOrNull?.revision.value ?? 'Unavailable'})\nCurrent evaluation revision ${r.latestEvaluation?.revision.value ?? 'Unavailable'}\nApplication version ${r.application.version}\nThis does not record a replacement decision.',
                  input: decisionReason,
                )) {
                  await controller.command((captured) async {
                    await controller.service.reverse(
                      captured,
                      decisionReason.text.trim(),
                    );
                  }, reviewed: r);
                }
              },
              enabled:
                  currentAttemptReviewed &&
                  r.application.status == ApplicationStatus.decision,
            ),
        ],
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 6),
        _eyebrow('Recommendation'),
        _scoreBar('Combined', metrics[2].$2, metrics[2].$3),
        for (final (index, component) in [(0, 'match'), (1, 'interview')])
          _scoreBar(
            weights?[component] == null
                ? metrics[index].$1
                : '${metrics[index].$1} · ${percent(weights?[component], ratio: true)}',
            metrics[index].$2,
            metrics[index].$3,
          ),
        ...[
          const Divider(),
          const SizedBox(height: 10),
          _eyebrow('Other actions'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, bounds) {
              final twoColumns =
                  bounds.maxWidth >= 260 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 16;
              final width = twoColumns
                  ? (bounds.maxWidth - 8) / 2
                  : bounds.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _decisionAction(
                    width,
                    'Reschedule',
                    Icons.calendar_today_outlined,
                    r.latestAttempt &&
                        r.interview?.status == 'SCHEDULED' &&
                        r.interview?.workflowState == 'SCHEDULED' &&
                        !finalStage,
                    () => recover(false),
                  ),
                  _decisionAction(
                    width,
                    'New attempt',
                    Icons.add,
                    canReopen,
                    () => recover(true),
                  ),
                  _decisionAction(
                    width,
                    'Early override',
                    Icons.bolt_outlined,
                    currentAttemptReviewed && d == null && !finalStage,
                    () => _earlyOverride(r),
                  ),
                  _decisionAction(
                    width,
                    'Rerun evaluation',
                    Icons.refresh,
                    r.latestAttempt &&
                        r.interview?.status == 'DONE' &&
                        r.interview?.completedAt != null &&
                        r.interview?.completionOutcome == 'USABLE' &&
                        r.latestEvaluation?.terminal == true,
                    () => _rerunEvaluation(r),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'If this interview changes while you are reviewing, you will be asked to refresh before acting.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: context.themeForeground(const Color(0xFF5F6C85)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _decisionAction(
    double width,
    String label,
    IconData icon,
    bool eligible,
    VoidCallback action,
  ) => SizedBox(
    width: width,
    child: OutlinedButton(
      onPressed: eligible && controller.canCommand ? action : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        side: BorderSide(color: context.themeOutline(const Color(0xFFE2E8F2))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    ),
  );

  Future<void> _earlyOverride(RecruitmentReview review) async {
    final outcome = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Early decision override'),
        children: [
          for (final outcome in ['HIRE', 'REJECT'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, outcome),
              child: Text(_displayStatus(outcome)),
            ),
        ],
      ),
    );
    if (mounted && outcome != null && controller.canCommand) {
      await decision(outcome, override: true, reviewed: review);
    }
  }

  Future<void> _rerunEvaluation(RecruitmentReview review) async {
    if (!await confirm(
          'Rerun latest evaluation?',
          'Revision ${review.latestEvaluation?.revision.value}\nCurrent score will be invalidated while new evidence is processed.',
          input: reason,
        ) ||
        !mounted) {
      return;
    }
    await controller.command((captured) async {
      await controller.service.rerun(captured, reason.text.trim());
    }, reviewed: review);
  }

  Widget _workspace(RecruitmentReview? r) {
    final notices = <Widget>[
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
        line('Retry permitted after ${localTime(controller.retryAt)}'),
    ];
    if (r == null) {
      return ListView(padding: const EdgeInsets.all(20), children: notices);
    }
    final tabs = DefaultTabController(
      key: ValueKey(_tab),
      length: _tabs.length,
      initialIndex: _tab,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: (index) => setState(() => _tab = index),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: context.themeForeground(const Color(0xFF16213A)),
        labelColor: context.themeForeground(const Color(0xFF16213A)),
        unselectedLabelColor: context.themeForeground(const Color(0xFF3D4A63)),
        dividerColor: context.themeOutline(const Color(0xFFE2E8F2)),
        tabs: [
          for (final (index, label) in _tabs.indexed)
            Tab(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (index == 2 || index == 3) ...[
                    const SizedBox(width: 8),
                    _pill(
                      '${index == 2 ? r.latestEvaluation?.questionCount ?? r.interview?.questions.length ?? 0 : r.feedback.length}',
                      const Color(0xFF5F6C85),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    final summary = _reviewHeader(r);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1560),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide =
                bounds.maxWidth >= 1181 &&
                bounds.maxHeight >= 440 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            if (!wide) {
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  summary,
                  const SizedBox(height: 14),
                  tabs,
                  const SizedBox(height: 14),
                  ...notices,
                  decisions(r),
                  ..._tabContent(r),
                ],
              );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                (bounds.maxWidth * .02).clamp(14, 28),
                14,
                (bounds.maxWidth * .02).clamp(14, 28),
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: bounds.maxHeight * .35,
                    ),
                    child: SingleChildScrollView(
                      primary: false,
                      child: summary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  tabs,
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, viewport) => ListView(
                              key: PageStorageKey(
                                'review-${r.interview?.id}-$_tab',
                              ),
                              primary: false,
                              children: [
                                ...notices,
                                ..._tabContent(
                                  r,
                                  viewportHeight: viewport.maxHeight,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 340,
                          child: LayoutBuilder(
                            builder: (context, viewport) =>
                                decisions(r, height: viewport.maxHeight + 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _eyebrow(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: context.themeForeground(const Color(0xFF3D4A63)),
    ),
  );

  Widget _pill(String label, Color color) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      child: Text(
        label,
        style: TextStyle(
          color: context.themeForeground(color),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _reviewCard(
    String title, {
    Widget? badge,
    Widget? leading,
    double? height,
    required List<Widget> children,
  }) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return SizedBox(
      height: height,
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: context.themeSurface(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: context.themeOutline(const Color(0xFFE2E8F2)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final titleRow = Row(
                    children: [
                      if (leading != null) ...[
                        leading,
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            letterSpacing: -.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                  if (badge != null &&
                      (bounds.maxWidth < 230 ||
                          MediaQuery.textScalerOf(context).scale(13) > 16)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleRow,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: badge),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: titleRow),
                      if (badge != null) ...[const SizedBox(width: 10), badge],
                    ],
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              color: context.themeOutline(const Color(0xFFEDF1F7)),
            ),
            if (height != null)
              Expanded(
                child: SingleChildScrollView(primary: false, child: body),
              )
            else
              body,
          ],
        ),
      ),
    );
  }

  String _scheduleTime(DateTime? time) {
    if (time == null) return 'Unavailable';
    final local = time.toLocal();
    final formats = MaterialLocalizations.of(context);
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
    final date = '${local.day} ${months[local.month - 1]}';
    return '$date, ${formats.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
  }

  String _displayStatus(String value) => value
      .toLowerCase()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  Widget _reviewHeader(RecruitmentReview r) {
    final interview = r.interview;
    final app = r.application;
    final name = app.candidateName?.trim().isNotEmpty == true
        ? app.candidateName!.trim()
        : app.candidateEmail.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    Widget field(String label, Widget content) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [_eyebrow(label), const SizedBox(height: 4), content],
    );
    Widget status(String label, String value, Color color) => field(
      label,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            _displayStatus(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFE4F5F0),
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF067A63),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Candidate unavailable' : name,
                style: const TextStyle(
                  fontSize: 17,
                  letterSpacing: -.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${app.jobTitle} · Application v${app.version}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: context.themeSurface(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.themeOutline(const Color(0xFFE2E8F2)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final fields = <Widget>[
            identity,
            status('Stage', app.status.value, _reviewBlue),
            if (interview != null) ...[
              status('Workflow', interview.workflowState, _reviewBlue),
              status(
                'Completion',
                interview.completionOutcome,
                interview.completionOutcome == 'USABLE'
                    ? _reviewTeal
                    : _reviewAmber,
              ),
              status(
                'Evaluation',
                interview.evaluationStatus,
                interview.evaluationStatus == 'READY'
                    ? _reviewTeal
                    : _reviewAmber,
              ),
              field(
                'Schedule',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scheduled ${_scheduleTime(interview.scheduledAt)}'),
                    Text('Completed ${_scheduleTime(interview.completedAt)}'),
                  ],
                ),
              ),
              SizedBox(
                width: 210,
                child: field(
                  'Attempt',
                  DropdownButtonFormField<String>(
                    key: ValueKey(interview.id),
                    initialValue: r.attempts.any((a) => a.id == interview.id)
                        ? interview.id
                        : null,
                    isExpanded: true,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: context.themeForeground(const Color(0xFF16213A)),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      constraints: const BoxConstraints(maxHeight: 36),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      for (final (index, entry) in r.attempts.indexed)
                        DropdownMenuItem(
                          value: entry.id,
                          child: Text(
                            'Attempt ${r.attempts.length - index}${index == 0 ? ' · Latest' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: controller.busy || controller.loading
                        ? null
                        : (id) {
                            if (id == null || id == interview.id) return;
                            setState(
                              () => transcriptId = compareTranscriptId =
                                  evaluationId = compareEvaluationId = null,
                            );
                            controller.selectAttempt(id);
                          },
                  ),
                ),
              ),
            ],
          ];
          return Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              for (final (index, item) in fields.indexed)
                if (index == 0 || bounds.maxWidth < 1140)
                  item
                else
                  Container(
                    padding: const EdgeInsets.only(left: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: context.themeOutline(const Color(0xFFEDF1F7)),
                        ),
                      ),
                    ),
                    child: item,
                  ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _tabContent(RecruitmentReview r, {double? viewportHeight}) {
    switch (_tab) {
      case 1:
        return [
          if (r.interview != null)
            RecruiterInterviewDashboard(
              key: ValueKey(r.interview!.id),
              review: r,
              service: controller.service,
              refreshVersion: _dashboardRefresh,
              viewportHeight: viewportHeight,
            )
          else
            section('Evidence', [
              const Text('No interview attempt available.'),
            ]),
        ];
      case 2:
        return [_evaluationPage(r, viewportHeight)];
      case 3:
        return [_feedbackPage(r, viewportHeight)];
      case 4:
        return [_historyPage(r, viewportHeight)];
      default:
        return [_overviewPage(r, viewportHeight)];
    }
  }

  List<(String, double?, Color)> _metrics(RecruitmentReview r) {
    final score = r.latestAttempt ? controller.currentScore : null;
    return [
      (
        'Screening match',
        score?.match ??
            (r.application.screening?.status == 'SUCCEEDED'
                ? r.application.screening?.matchScore
                : null),
        _reviewBlue,
      ),
      (
        'Interview score',
        score?.interview ?? r.latestEvaluation?.score,
        _reviewRed,
      ),
      ('Combined', score?.publishedCombined, _reviewAmber),
    ];
  }

  Widget _cardGrid(List<Widget> cards) => LayoutBuilder(
    builder: (context, bounds) => bounds.maxWidth >= 620
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, card) in cards.indexed) ...[
                if (index > 0) const SizedBox(width: 14),
                Expanded(child: card),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
  );

  Widget _contribution(RecruitmentReview r) {
    final score = r.latestAttempt ? controller.currentScore : null;
    final weights = score?.weights ?? const {};
    if (weights.isEmpty || score?.publishedCombined == null) {
      return const Text('Score contribution is unavailable.');
    }
    final components = [
      ('Screening', score?.match, weights['match'], _reviewBlue),
      ('Interview', score?.interview, weights['interview'], _reviewTeal),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value, weight, color) in components)
          _scoreBar(
            '$label · ${percent(weight, ratio: true)} weight',
            value == null || weight == null ? null : value * weight,
            color,
          ),
      ],
    );
  }

  Widget _coverageMap(RecruitmentReview review, EvaluationRevision evaluation) {
    final extraction = evaluation.extraction;
    final transcript = evaluation.frozenTranscript(review.transcripts!);
    if (extraction == null || transcript == null || transcript.turns.isEmpty) {
      return const Text('Transcript coverage map unavailable.');
    }
    final unlinked = extraction.unmatchedTurnIds.toSet();
    final linked = {
      for (final answer in extraction.questions) ...[
        if (answer.askedTurnId != null) answer.askedTurnId!,
        ...answer.answerTurnIds,
        ...answer.followUpTurnIds,
        ...answer.spans.map((span) => span.turnId),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, bounds) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final turn in transcript.turns)
                SizedBox(
                  width: (bounds.maxWidth - 48) / 9,
                  height: 30,
                  child: Tooltip(
                    message:
                        linked.contains(turn.id) && !unlinked.contains(turn.id)
                        ? 'Linked to a question'
                        : 'Not linked to a question',
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: context.themeForeground(
                          linked.contains(turn.id) &&
                                  !unlinked.contains(turn.id)
                              ? const Color(0xFF3D4A63)
                              : const Color(0xFF8A5A00),
                        ),
                        backgroundColor: context.themeSurface(
                          linked.contains(turn.id) &&
                                  !unlinked.contains(turn.id)
                              ? const Color(0xFFEEF3F9)
                              : const Color(0xFFFFF3DC),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      onPressed: () => showTurn(transcript, turn.id),
                      child: Text(
                        turn.id,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            const Text(
              '▪ Linked to a question',
              style: TextStyle(fontSize: 13),
            ),
            Text(
              '▪ Not linked (${transcript.turns.where((t) => !linked.contains(t.id) || unlinked.contains(t.id)).length})',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A5A00)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _questionTypes(RecruitmentReview r, {double? height}) {
    final evaluation = r.latestEvaluation;
    final groups = <String, List<InterviewQuestion>>{
      'BEHAVIORAL': [],
      'TECHNICAL': [],
      'SITUATIONAL': [],
    };
    final questions = evaluation?.questions.isNotEmpty == true
        ? evaluation!.questions
        : r.interview?.questions ?? const <InterviewQuestion>[];
    if (questions.isEmpty) return const SizedBox.shrink();
    for (final question in questions) {
      final category = question.category.trim().toUpperCase();
      (groups[category.isEmpty ? 'QUESTIONS' : category] ??= []).add(question);
    }
    final scores = {
      if (evaluation?.status == 'READY')
        for (final answer in evaluation!.answers)
          answer.questionId: answer.scoreOutOfTen,
    };
    return _cardGrid([
      for (final group in groups.entries)
        _questionTypeCard(group.key, group.value, scores, height: height),
    ]);
  }

  Widget _questionTypeCard(
    String category,
    List<InterviewQuestion> questions,
    Map<String, double?> scores, {
    double? height,
  }) {
    final values = questions.map((q) => scores[q.id]).whereType<double>();
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final color = reviewAnswerScoreColor(average);
    return _reviewCard(
      _displayStatus(category),
      height: height,
      leading: ReviewQuestionBadge(category: category),
      badge: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: average?.toStringAsFixed(1) ?? '—',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.themeForeground(color),
              ),
            ),
            if (average != null) const TextSpan(text: ' /10'),
          ],
        ),
      ),
      children: [
        if (average != null)
          LinearProgressIndicator(
            value: average / 10,
            color: reviewAnswerProgressColor(average),
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: context.themeChartTrack(const Color(0xFFE7ECF4)),
          ),
        if (questions.isEmpty) const Text('No questions in this category.'),
        for (final question in questions) ...[
          const Divider(height: 22),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: height == null || questions.isEmpty
                  ? 8
                  : (((height - 99) / questions.length - 60) / 2).clamp(
                      8.0,
                      28.0,
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  scores[question.id]?.toStringAsFixed(1) ?? '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.themeForeground(
                      reviewAnswerScoreColor(scores[question.id]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _recommendation(RecruitmentReview r, {double? height}) {
    final score = r.latestAttempt ? controller.currentScore : null;
    final coverage =
        (r.latestAttempt ? controller.currentScore?.answerCoverage : null) ??
        r.latestEvaluation?.coverage;
    final weights = score?.weights;
    final answers = r.latestEvaluation?.assessedCount;
    final metrics = _metrics(r);
    final interviewScore = metrics[1].$2;
    final weightSplit = ['match', 'interview', 'behavioral']
        .map((key) => weights?[key])
        .whereType<double>()
        .where((value) => value > 0)
        .map((value) => (value * 100).toStringAsFixed(0))
        .join(' / ');
    String weight(String key) => percent(weights?[key], ratio: true);
    final descriptions = [
      weights?['match'] == null
          ? 'Resume vs role'
          : 'Resume vs role · weight ${weight('match')}',
      [
        if (answers != null)
          '$answers answers${interviewScore == null ? '' : ', average ${(interviewScore / 10).toStringAsFixed(1)} / 10'}',
        if (weights?['interview'] != null) 'weight ${weight('interview')}',
      ].join(' · '),
      if (weightSplit.isNotEmpty) 'Weighted $weightSplit' else '',
    ];
    final contributions = [
      ('Screening', score?.match, weights?['match'], const Color(0xFF6C93F7)),
      (
        'Interview',
        score?.interview,
        weights?['interview'],
        const Color(0xFF2FCDB3),
      ),
      (
        'Behavioral',
        score?.breakdown['behavioral'],
        weights?['behavioral'],
        const Color(0xFFCBD5E4),
      ),
    ];
    return _reviewCard(
      'Recommendation',
      height: height,
      badge: score?.publishedCombined != null && coverage == 1
          ? _pill('✓  COMPLETE · FULL COVERAGE', _reviewTeal)
          : null,
      children: [
        LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 385;
            final tiles = [
              for (final (index, metric) in metrics.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: index == 2
                        ? const Color(0xFF16213A)
                        : context.themeSurface(const Color(0xFFFAFBFD)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.themeOutline(
                        index == 2
                            ? const Color(0xFF16213A)
                            : const Color(0xFFEDF1F7),
                      ),
                    ),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: index == 2
                          ? const Color(0xFFA9B5CE)
                          : context.themeForeground(const Color(0xFF3D4A63)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (index == 2 ? 'Combined' : metric.$1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          percent(metric.$2),
                          style: TextStyle(
                            fontSize: 30,
                            letterSpacing: -1,
                            fontWeight: FontWeight.w600,
                            color: index == 2
                                ? Colors.white
                                : context.themeForeground(
                                    const Color(0xFF16213A),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        if (descriptions[index].isNotEmpty)
                          Text(
                            descriptions[index],
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ),
            ];
            return wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, tile) in tiles.indexed) ...[
                          if (index > 0) const SizedBox(width: 12),
                          Expanded(child: tile),
                        ],
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: tiles,
                  );
          },
        ),
        if (score?.publishedCombined != null && weights != null) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, bounds) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: context.themeChartTrack(const Color(0xFFE7ECF4)),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final (_, value, factor, color) in contributions)
                        if (value != null && factor != null && factor > 0)
                          SizedBox(
                            width:
                                bounds.maxWidth *
                                value.clamp(0, 100) *
                                factor /
                                100,
                            child: ColoredBox(color: color),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              for (final (label, value, factor, color) in contributions)
                if (factor != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.square_rounded,
                              size: 9,
                              color: color,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: factor == 0
                              ? '$label · weight 0 · excluded'
                              : value == null
                              ? '$label · weight ${percent(factor, ratio: true)}'
                              : '$label ${value.toStringAsFixed(1)} × $factor = ${(value * factor).toStringAsFixed(1)}',
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _checklist(RecruitmentReview r, {double? height}) {
    final coverage =
        (r.latestAttempt ? controller.currentScore?.answerCoverage : null) ??
        r.latestEvaluation?.coverage;
    final evaluationReady =
        r.interview?.evaluationStatus == 'READY' &&
        r.latestEvaluation?.status == 'READY';
    final latestRelease = r.feedback
        .where((report) => report.releasedAt != null)
        .firstOrNull;
    final sent = latestRelease != null && latestRelease.retractedAt == null;
    final report = _checklistReport?.report;
    final availability = _checklistLoading
        ? 'Loading…'
        : switch (_checklistReport?.availability) {
            'pending' => 'Pending',
            'disabled' => 'Disabled',
            _ => 'Unavailable',
          };
    final expression = report?.snapshot.expressionStatus;
    final entries = [
      (
        'Evaluation ready',
        evaluationReady
            ? 'Latest'
            : _displayStatus(r.interview?.evaluationStatus ?? 'Unavailable'),
        evaluationReady,
        2,
      ),
      ('Answer coverage', percent(coverage, ratio: true), coverage == 1, 2),
      (
        'Proctoring flags',
        report == null
            ? availability
            : '${report.episodes.length}${report.episodesTruncated ? '+' : ''} events',
        report != null && report.episodes.isEmpty,
        1,
      ),
      (
        'Emotion timeline (FER)',
        expression == 'disabled'
            ? 'Not collected'
            : expression == null
            ? availability
            : _displayStatus(expression),
        report?.expressionPercentages.isNotEmpty == true,
        1,
      ),
      (
        'Candidate feedback',
        sent
            ? 'Sent to candidate'
            : latestRelease?.retractedAt != null
            ? 'Withdrawn'
            : r.feedback.isEmpty
            ? 'Not prepared'
            : r.feedback.first.status == 'READY'
            ? 'Ready to release'
            : _displayStatus(r.feedback.first.status),
        sent,
        3,
      ),
    ];
    return _reviewCard(
      'Review checklist',
      height: height,
      children: [
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0)
            Divider(
              height: 1,
              color: context.themeOutline(const Color(0xFFEDF1F7)),
            ),
          InkWell(
            onTap: () => setState(() => _tab = entry.$4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: context.themeSurface(
                      entry.$3
                          ? const Color(0xFFE4F5F0)
                          : const Color(0xFFEDF1F7),
                    ),
                    child: Icon(
                      entry.$3 ? Icons.check : Icons.remove,
                      size: 14,
                      color: context.themeForeground(
                        entry.$3 ? _reviewTeal : const Color(0xFF5F6C85),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      entry.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.themeForeground(const Color(0xFF5F6C85)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _scoreBar(String label, double? value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              percent(value),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            color: color,
            backgroundColor: context.themeChartTrack(const Color(0xFFE7ECF4)),
            minHeight: 6,
            value: (value / 100).clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = controller.review;
    final dashboard = widget.showInterviewDashboard;
    final refreshAction = IconButton(
      tooltip: 'Refresh review',
      onPressed: controller.busy || controller.loading ? null : _refresh,
      icon: const Icon(Icons.refresh),
    );
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme
            .apply(fontFamily: 'Inter')
            .copyWith(
              bodyMedium: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.45,
                color: context.themeForeground(const Color(0xFF16213A)),
              ),
              bodyLarge: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: context.themeForeground(const Color(0xFF16213A)),
              ),
            ),
        dividerTheme: DividerThemeData(
          color: context.themeOutline(const Color(0xFFEDF1F7)),
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF5F6C85)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: context.themeOutline(const Color(0xFFE2E8F2)),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: context.themeOutline(const Color(0xFFE2E8F2)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.themeForeground(const Color(0xFF16213A)),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: BorderSide(
              color: context.themeOutline(const Color(0xFFE2E8F2)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: context.themeForeground(const Color(0xFF2C52C4)),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16213A),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: context.themeSurface(Colors.white),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: context.themeForeground(const Color(0xFF16213A)),
          ),
          contentTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.6,
            color: context.themeForeground(const Color(0xFF3D4A63)),
          ),
        ),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Inter'),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: dashboard
            ? null
            : AppBar(
                title: const Text('Recruiter evidence and decisions'),
                actions: [refreshAction],
              ),
        body: Column(
          children: [
            if (dashboard)
              SafeArea(
                bottom: false,
                child: InterviewReviewTopBar(
                  onBack: () => Navigator.of(context).maybePop(),
                  onRefresh: controller.busy || controller.loading
                      ? null
                      : _refresh,
                ),
              )
            else
              const RecruiterTopBar(pageTitle: 'Evidence review'),
            if (controller.loading || controller.busy)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.45,
                  color: context.themeForeground(const Color(0xFF16213A)),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: _workspace(r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
