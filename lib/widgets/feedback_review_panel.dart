import 'package:skillsense_ai/theme/app_typography.dart';
import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';
import '../models/recruitment_evidence.dart';
import '../services/recruitment_review_controller.dart';
import 'feedback_content_view.dart';

class FeedbackReviewPanel extends StatefulWidget {
  const FeedbackReviewPanel({
    super.key,
    required this.controller,
    this.availableHeight,
  });
  final double? availableHeight;
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
    final c = widget.controller;
    final captured = c.review!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw candidate feedback?'),
        content: SizedBox(
          width: 472,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Version ${report.revision.value} · The candidate will lose access to this report. An older release will not be restored. Already-read content cannot be recalled.',
              ),
              const SizedBox(height: 16),
              TextField(
                style: AppType.body.style(context),
                controller: reason,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Private reason (required)',
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
            listenable: reason,
            builder: (context, _) => FilledButton(
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Withdraw report'),
            ),
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

  String _time(DateTime value) {
    final local = value.toLocal();
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
    return '${local.day} ${months[local.month - 1]} ${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, review = c.review!;
    final latest = review.feedback.firstOrNull;
    final latestRelease = review.feedback
        .where((f) => f.releasedAt != null)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (review.feedback.isEmpty)
          const Text('No feedback projection is available.'),
        for (final f in review.feedback)
          Container(
            constraints: BoxConstraints(
              minHeight:
                  widget.availableHeight == null || review.feedback.isEmpty
                  ? 0
                  : ((widget.availableHeight! -
                                (review.feedback.length - 1) * 14) /
                            review.feedback.length)
                        .clamp(0.0, double.infinity),
            ),
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: context.themeSurface(Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.themeOutline(const Color(0xFFE2E8F2)),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0816213A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Version ${f.revision.value}',
                      style: AppType.h4.style(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: context.themeSurface(
                          f.error?.isNotEmpty == true
                              ? const Color(0xFFFCEEF0)
                              : f.releasedAt != null && f.retractedAt == null
                              ? const Color(0xFFE4F5F0)
                              : const Color(0xFFEEF2F8),
                        ),
                      ),
                      child: Text(
                        f.retractedAt != null
                            ? 'WITHDRAWN'
                            : f.releasedAt != null
                            ? 'SENT TO CANDIDATE'
                            : f.error?.isNotEmpty == true
                            ? 'NOT PREPARED'
                            : f.status,
                        style: AppType.badge.style(
                          context,
                          color: context.themeForeground(
                            f.error?.isNotEmpty == true
                                ? const Color(0xFFA52F43)
                                : f.releasedAt != null && f.retractedAt == null
                                ? const Color(0xFF067A63)
                                : TypographyColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 24),
                        ),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Version ${f.revision.value} · Report details',
                            ),
                            content: SelectableText(
                              'Evaluation ${f.evaluation ?? 'Unavailable'} · Edit ${f.editVersion.value}\nHash ${f.hash}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.info_outline, size: 14),
                        label: const Text('Details'),
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 24,
                  color: context.themeOutline(const Color(0xFFEDF1F7)),
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
                      ? 'Sent to the candidate on ${_time(f.releasedAt!)}${latestRelease?.id != f.id ? ' · superseded' : ''}'
                      : 'Unreleased',
                ),
                const SizedBox(height: 12),
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
                                    f.amendments['summary']?.toString() ?? '';
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
                        onPressed: c.canCommand ? () => retract(f) : null,
                        child: const Text('Withdraw feedback'),
                      ),
                  ],
                ),
                if (editing == f.id &&
                    f.releasedAt == null &&
                    f.retractedAt == null) ...[
                  TextField(
                    style: AppType.body.style(context),
                    controller: summary,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Public coaching summary',
                    ),
                  ),
                  TextField(
                    style: AppType.body.style(context),
                    controller: suggestions,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText:
                          'Public practice suggestions — one per line, up to 10',
                    ),
                  ),
                  CheckboxListTile(
                    value: acknowledged,
                    onChanged: (v) => setState(() => acknowledged = v == true),
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
        if (editing != null)
          TextField(
            style: AppType.body.style(context),
            controller: reason,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText:
                  'Private reason for guidance edit or withdrawal (required)',
            ),
          ),
      ],
    );
  }
}
