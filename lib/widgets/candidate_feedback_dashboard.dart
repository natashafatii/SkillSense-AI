import 'package:skillsense_ai/constants/adaptive_colors.dart';
import 'package:flutter/material.dart';

import '../models/candidate_feedback.dart';

class CandidateFeedbackDashboard extends StatelessWidget {
  const CandidateFeedbackDashboard({super.key, required this.content});

  final FeedbackContent content;

  static const _ink = Color(0xFF1B2740);
  static const _muted = Color(0xFF687893);
  static const _teal = Color(0xFF0EB489);
  static const _line = Color(0xFFE7EBF2);
  static const _blue = Color(0xFF3E6FF0);

  @override
  Widget build(BuildContext context) {
    final highlights = _findings(
      context,
      'What worked',
      content.strengths,
      const Color(0xFF087C63),
      '▲',
    );
    final coaching = _findings(
      context,
      'Work on next',
      content.suggestions,
      const Color(0xFFA36717),
      '◆',
    );
    final questions = _section(context, 'Question by question', [
      if (content.questions.isEmpty)
        _row(
          context,
          Text(
            'Question scores are unavailable.',
            style: TextStyle(color: context.themeForeground(_muted)),
          ),
        ),
      for (final question in content.questions)
        _row(
          context,
          Row(
            children: [
              Tooltip(
                message: question.category,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.themeSurface(const Color(0xFFD8F3ED)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    question.category.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: context.themeForeground(const Color(0xFF086D5D)),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(question.text)),
              const SizedBox(width: 12),
              _scoreRing(context, question.percentage, large: false),
            ],
          ),
        ),
    ]);

    return DefaultTextStyle.merge(
      style: TextStyle(color: context.themeForeground(_ink), fontSize: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _overview(context),
                    const SizedBox(height: 14),
                    highlights,
                    const SizedBox(height: 14),
                    coaching,
                    const SizedBox(height: 14),
                    questions,
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 36, child: _overview(context)),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 64,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: highlights),
                                const SizedBox(width: 14),
                                Expanded(child: coaching),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          questions,
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (content.gaps.isNotEmpty ||
              content.publicSummary != null ||
              content.publicSuggestions.isNotEmpty ||
              content.limitations.isNotEmpty)
            ExpansionTile(
              title: const Text('Report details'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              expandedAlignment: Alignment.centerLeft,
              children: [
                for (final gap in content.gaps) Text(gap.text),
                if (content.publicSummary case final summary?) Text(summary),
                for (final suggestion in content.publicSuggestions)
                  Text(suggestion),
                for (final limitation in content.limitations) Text(limitation),
              ],
            ),
        ],
      ),
    );
  }

  Widget _overview(BuildContext context) => _surface(
    context,
    accent: true,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YOUR INTERVIEW',
            style: TextStyle(
              color: context.themeForeground(_muted),
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _scoreRing(context, content.performance, large: true),
          const SizedBox(height: 14),
          Text(
            content.summary,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (content.dimensions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: context.themeOutline(_line)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final dimension in content.dimensions)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dimension.label.toUpperCase(),
                        style: TextStyle(
                          color: context.themeForeground(_muted),
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        (dimension.percentage / 10).toStringAsFixed(1),
                        semanticsLabel:
                            '${(dimension.percentage / 10).toStringAsFixed(1)} out of 10',
                        style: TextStyle(
                          color: dimension.id.startsWith('technical.')
                              ? context.themeForeground(const Color(0xFF087C63))
                              : _blue,
                          fontSize: 15,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _findings(
    BuildContext context,
    String title,
    List<FeedbackFinding> findings,
    Color color,
    String marker,
  ) => _section(context, title, [
    if (findings.isEmpty)
      _row(
        context,
        Text(
          'No items in this report.',
          style: TextStyle(color: context.themeForeground(_muted)),
        ),
      ),
    for (final finding in findings)
      _row(
        context,
        Row(
          children: [
            ExcludeSemantics(
              child: Text(marker, style: TextStyle(color: color, fontSize: 9)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(finding.text)),
          ],
        ),
      ),
  ]);

  Widget _section(BuildContext context, String title, List<Widget> rows) =>
      _surface(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...rows,
          ],
        ),
      );

  Widget _row(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.themeOutline(_line))),
    ),
    child: child,
  );

  Widget _surface(
    BuildContext context, {
    required Widget child,
    bool accent = false,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.themeSurface(const Color(0xFFFAFBFC)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: accent ? const Color(0x2619C9AB) : const Color(0x120F172A),
          blurRadius: accent ? 28 : 12,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: accent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_teal, _blue, Colors.transparent],
                    ),
                  ),
                ),
                child,
              ],
            )
          : child,
    ),
  );

  Widget _scoreRing(
    BuildContext context,
    double? score, {
    required bool large,
  }) => SizedBox.square(
    dimension: large ? 138 : 36,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: CircularProgressIndicator(
            value: (score ?? 0) / 100,
            backgroundColor: context.themeSurface(const Color(0xFFE5E7EB)),
            color: large || (score != null && score >= 75) ? _teal : _blue,
            strokeWidth: large ? 9 : 4,
            strokeAlign: BorderSide.strokeAlignInside,
            padding: EdgeInsets.zero,
            trackGap: 0,
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.toStringAsFixed(0) ?? '—',
                semanticsLabel: score == null
                    ? 'Score unavailable'
                    : '${score.toStringAsFixed(0)} percent',
                style: TextStyle(
                  fontSize: large ? 37 : 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (large)
                Text(
                  'OVERALL',
                  style: TextStyle(
                    color: context.themeForeground(_muted),
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
