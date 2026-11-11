import 'package:flutter/material.dart';
import '../models/recruitment_evidence.dart';
import '../services/recruitment_review_controller.dart';
import 'feedback_content_view.dart';

class FeedbackReviewPanel extends StatefulWidget {
  const FeedbackReviewPanel({super.key, required this.controller});
  final RecruitmentReviewController controller;
  @override
  State<FeedbackReviewPanel> createState() => _FeedbackReviewPanelState();
}

class _FeedbackReviewPanelState extends State<FeedbackReviewPanel> {
  final summary = TextEditingController(),
      suggestions = TextEditingController(),
      reason = TextEditingController();
  String? editing;
  bool acknowledged = false;
  @override
  void dispose() {
    summary.dispose();
    suggestions.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> preview(
    FeedbackReviewRevision report, {
    required bool release,
  }) async {
    final controller = widget.controller;
    final captured = controller.review!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Candidate preview · revision ${report.revision.value} · edit ${report.editVersion.value}',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is candidate-visible content. Private evaluation evidence is shown separately on the review page.',
                ),
                const SizedBox(height: 16),
                FeedbackContentView(content: report.content!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          if (release)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Release this exact preview'),
            ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await controller.command(
        (_) => controller.service.releaseFeedback(report),
        reviewed: captured,
      );
    }
  }

  Future<void> retract(FeedbackReviewRevision report) async {
    if (reason.text.trim().isEmpty) return;
    final c = widget.controller;
    final captured = c.review!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw candidate feedback?'),
        content: Text(
          'Revision ${report.revision.value}, edit ${report.editVersion.value}. The candidate will lose access to this report. An older release will not be restored. Already-read content cannot be recalled.\nPrivate reason: ${reason.text}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw report'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await c.command(
        (r) => c.service.retractFeedback(r, report, reason.text),
        reviewed: captured,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, review = c.review!;
    final latest = review.feedback.firstOrNull;
    final latestRelease = review.feedback
        .where((f) => f.releasedAt != null)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Candidate feedback review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Measured evidence is immutable. New unreleased revisions do not replace a previously released report.',
            ),
            if (review.feedback.isEmpty)
              const Text('No feedback projection is available.'),
            for (final f in review.feedback)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Revision ${f.revision.value} · ${f.status} · Edit ${f.editVersion.value}',
                    ),
                    if (f.error == 'EVALUATION_UNAVAILABLE')
                      const Text(
                        'Feedback is blocked because the answer evaluation is unavailable. '
                        'Review its failure details and request a new evaluation revision. '
                        'This does not mean the candidate failed the interview.',
                      ),
                    Text(
                      f.retractedAt != null
                          ? 'Withdrawn · cannot be released again'
                          : f.releasedAt != null
                          ? 'Released ${f.releasedAt!.toLocal()}${latestRelease?.id != f.id ? ' · superseded' : ''}'
                          : 'Unreleased',
                    ),
                    Text(
                      'Evaluation ${f.evaluation ?? 'Unavailable'} · Hash ${f.hash}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (f.content != null)
                          OutlinedButton(
                            onPressed: c.canCommand
                                ? () => preview(f, release: false)
                                : null,
                            child: const Text('Preview candidate content'),
                          ),
                        if (f.content != null &&
                            f.releasedAt == null &&
                            f.retractedAt == null &&
                            latest?.id == f.id &&
                            f.evaluation == review.latestEvaluation?.id &&
                            review.interview?.status == 'DONE' &&
                            review.interview?.completedAt != null &&
                            review.interview?.completionOutcome == 'USABLE' &&
                            review.latestAttempt)
                          FilledButton(
                            onPressed: c.canCommand
                                ? () => preview(f, release: true)
                                : null,
                            child: const Text('Review and release'),
                          ),
                        if (f.content != null &&
                            f.releasedAt == null &&
                            f.retractedAt == null)
                          OutlinedButton(
                            onPressed: c.canCommand
                                ? () => setState(() {
                                    editing = f.id;
                                    acknowledged = false;
                                    summary.text =
                                        f.amendments['summary']?.toString() ??
                                        '';
                                    suggestions.text =
                                        (f.amendments['improvement_suggestions']
                                                    as List? ??
                                                [])
                                            .join('\n');
                                  })
                                : null,
                            child: const Text('Edit public guidance'),
                          ),
                        if (f.releasedAt != null &&
                            f.retractedAt == null &&
                            latestRelease?.id == f.id)
                          OutlinedButton(
                            onPressed:
                                c.canCommand && reason.text.trim().isNotEmpty
                                ? () => retract(f)
                                : null,
                            child: const Text('Retract feedback'),
                          ),
                      ],
                    ),
                    if (editing == f.id &&
                        f.releasedAt == null &&
                        f.retractedAt == null) ...[
                      TextField(
                        controller: summary,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Public coaching summary',
                        ),
                      ),
                      TextField(
                        controller: suggestions,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText:
                              'Public practice suggestions — one per line, up to 10',
                        ),
                      ),
                      CheckboxListTile(
                        value: acknowledged,
                        onChanged: (v) =>
                            setState(() => acknowledged = v == true),
                        title: const Text(
                          'I understand this guidance will be visible to the candidate when released.',
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            c.canCommand &&
                                acknowledged &&
                                reason.text.trim().isNotEmpty
                            ? () async {
                                final items = suggestions.text
                                    .split('\n')
                                    .map((v) => v.trim())
                                    .where((v) => v.isNotEmpty)
                                    .toList();
                                if (items.length > 10 ||
                                    items.any((v) => v.length > 500)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Use up to 10 suggestions of 500 characters each.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final ok = await c.command(
                                  (r) => c.service.editFeedback(
                                    r,
                                    f,
                                    commandReason: reason.text,
                                    acknowledged: acknowledged,
                                    amendments: {
                                      if (summary.text.trim().isNotEmpty)
                                        'summary': summary.text.trim(),
                                      'improvement_suggestions': items,
                                    },
                                  ),
                                );
                                if (ok && mounted) {
                                  setState(() {
                                    editing = null;
                                    acknowledged = false;
                                  });
                                }
                              }
                            : null,
                        child: const Text(
                          'Save public guidance — preview again before release',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            TextField(
              controller: reason,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText:
                    'Private reason for guidance edit or withdrawal (required)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
