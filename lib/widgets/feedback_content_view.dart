import 'package:flutter/material.dart';
import '../models/candidate_feedback.dart';

/// The same candidate-safe content is used for recruiter preview and release.
class FeedbackContentView extends StatelessWidget {
  const FeedbackContentView({super.key, required this.content});
  final FeedbackContent content;
  @override
  Widget build(BuildContext context) {
    final c = content;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interview answer performance: ${c.performance == null ? 'Unavailable' : '${c.performance!.toStringAsFixed(1)}%'}',
        ),
        Text(c.summary),
        Text(
          'Evidence coverage: ${(c.coverage * 100).toStringAsFixed(0)}% · ${c.assessedQuestions}/${c.totalQuestions} questions assessed',
        ),
        if (c.dimensions.isNotEmpty) heading('Performance dimensions'),
        for (final d in c.dimensions) ...[
          Text(
            '${d.label}: ${d.percentage.toStringAsFixed(1)}% (${d.assessedAnswers} assessed answers)',
          ),
          LinearProgressIndicator(value: d.percentage / 100),
        ],
        if (c.strengths.isNotEmpty) heading('Supported strengths'),
        for (final f in c.strengths) Text('• ${f.text}'),
        if (c.gaps.isNotEmpty) heading('Areas to improve'),
        for (final f in c.gaps) Text('• ${f.text}'),
        if (c.suggestions.isNotEmpty) heading('Practice suggestions'),
        for (final f in c.suggestions) Text('• ${f.text}'),
        if (c.publicSummary != null || c.publicSuggestions.isNotEmpty)
          heading('Recruiter guidance'),
        if (c.publicSummary != null) Text(c.publicSummary!),
        for (final s in c.publicSuggestions) Text('• $s'),
        if (c.limitations.isNotEmpty) heading('Report limitations'),
        for (final s in c.limitations) Text('• $s'),
      ],
    );
  }
}
