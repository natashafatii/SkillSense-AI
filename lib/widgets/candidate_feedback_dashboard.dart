import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/candidate_feedback.dart';
import 'candidate_feedback_visuals.dart';

class CandidateFeedbackDashboard extends StatelessWidget {
  const CandidateFeedbackDashboard({
    super.key,
    required this.content,
    this.attemptLabel,
    this.practised = const {},
    this.onPractised,
    this.details,
    this.searchQuery = '',
  });

  final FeedbackContent content;
  final String? attemptLabel;
  final Set<String> practised;
  final void Function(String dimensionId, bool value)? onPractised;
  final Widget? details;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final palette = FeedbackPalette(context);
    final dimensions = content.dimensions;
    final assessedCounts = dimensions
        .map((item) => item.assessedAnswers)
        .toSet();
    final commonCount = assessedCounts.length == 1
        ? assessedCounts.single
        : null;
    final hero = _overview(palette);
    final radar = FeedbackPanel(
      child: Column(
        children: [
          FeedbackPanelHeader(
            'Skill shape',
            trailing: Text(
              'SCALE 0–100%',
              style: palette.caption(uppercase: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                _SkillRadar(dimensions: dimensions),
                const SizedBox(height: 8),
                _radarLegend(palette),
              ],
            ),
          ),
        ],
      ),
    );
    final performance = FeedbackPanel(
      child: Column(
        children: [
          FeedbackPanelHeader(
            'Performance by skill',
            trailing: commonCount == null
                ? null
                : Text(
                    '$commonCount ${commonCount == 1 ? 'answer' : 'answers'} each',
                    style: palette.caption(),
                  ),
          ),
          for (final (index, dimension) in dimensions.indexed)
            _dimension(
              palette,
              dimension,
              index < dimensions.length - 1,
              commonCount == null,
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final three = width >= 962 * scale;
        final two = width >= 636 * scale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dimensions.isEmpty)
              hero
            else if (three)
              _alignedRow([hero, radar, performance])
            else ...[
              hero,
              const SizedBox(height: 14),
              if (two)
                _alignedRow([radar, performance])
              else ...[
                radar,
                const SizedBox(height: 14),
                performance,
              ],
            ],
            if (content.gaps.isNotEmpty || content.suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _coaching(context, palette),
            ],
            if (content.strengths.isNotEmpty) ...[
              const SizedBox(height: 14),
              _notes(
                palette,
                'What worked',
                content.strengths.map((item) => item.text),
              ),
            ],
            if (content.publicSummary != null ||
                content.publicSuggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _notes(palette, 'Recruiter guidance', [
                if (content.publicSummary case final summary?) summary,
                ...content.publicSuggestions,
              ]),
            ],
            if (content.questions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _notes(palette, 'Question by question', [
                for (final question in content.questions) question.text,
              ], questions: content.questions),
            ],
            if (details != null) ...[
              const SizedBox(height: 14),
              details!,
            ] else ...[
              if (content.limitations.isNotEmpty) ...[
                const SizedBox(height: 14),
                _notes(palette, 'Report limitations', content.limitations),
              ],
              if (content.questions.isEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'This report does not include individual question scores.',
                  style: palette.caption(),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _alignedRow(
    List<Widget> cards, {
    List<double>? weights,
    double gap = 16,
  }) {
    if (cards.length == 1) return cards.single;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, card) in cards.indexed) ...[
            if (index > 0) SizedBox(width: gap),
            Expanded(flex: (weights?[index] ?? 1).round(), child: card),
          ],
        ],
      ),
    );
  }

  Widget _overview(FeedbackPalette palette) {
    final score = content.performance;
    final best = content.dimensions.fold<double?>(
      null,
      (best, item) =>
          best == null ? item.percentage : math.max(best, item.percentage),
    );
    final coverage = feedbackPercentage(content.coverage * 100);
    final gaugeSize = (MediaQuery.sizeOf(palette.context).height * .17).clamp(
      132.0,
      172.0,
    );
    return FeedbackPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Column(
              children: [
                Text('YOUR INTERVIEW', style: palette.caption(uppercase: true)),
                if (attemptLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    attemptLabel!,
                    textAlign: TextAlign.center,
                    style: palette.text(size: 15, weight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 10),
                FeedbackGauge(size: gaugeSize, value: score),
                const SizedBox(height: 12),
                Text(
                  'Interview answer performance',
                  textAlign: TextAlign.center,
                  style: palette.text(
                    size: 18.5,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.summary,
                  textAlign: TextAlign.center,
                  style: palette.prose(),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.edge)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _metric(
                      palette,
                      'ASSESSED',
                      '${content.assessedQuestions}/${content.totalQuestions}',
                      palette.score(50),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: palette.edge),
                  Expanded(
                    child: _metric(
                      palette,
                      'EVIDENCE',
                      coverage,
                      palette.score(70),
                      label: 'Evidence coverage · $coverage',
                    ),
                  ),
                  if (best != null) ...[
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: palette.edge,
                    ),
                    Expanded(
                      child: _metric(
                        palette,
                        'BEST',
                        feedbackPercentage(best),
                        palette.score(best),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radarLegend(FeedbackPalette palette) {
    if (content.dimensions.isEmpty) return const SizedBox.shrink();
    final sorted = [...content.dimensions]
      ..sort((a, b) => a.percentage.compareTo(b.percentage));
    Widget legend(FeedbackDimension d, String prefix) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: palette.fill(d.percentage),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            '$prefix: ${_RadarPainter.shortLabel(d.label)} ${feedbackPercentage(d.percentage)}',
            style: palette.caption(),
          ),
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 6,
      children: [
        legend(sorted.last, 'Strongest'),
        legend(sorted.first, 'Practise most'),
        Text(
          '┄  50% mark',
          style: palette.caption().copyWith(color: FeedbackPalette.blue),
        ),
      ],
    );
  }

  Widget _metric(
    FeedbackPalette palette,
    String title,
    String value,
    Color color, {
    String? label,
  }) => Semantics(
    label: label ?? '$title: $value',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: palette.caption(uppercase: true)),
          Text(
            value,
            style: palette.number(size: 22, color: color, bold: true),
          ),
        ],
      ),
    ),
  );

  Widget _dimension(
    FeedbackPalette palette,
    FeedbackDimension dimension,
    bool divider,
    bool showCount,
  ) {
    final value = dimension.percentage;
    final count = dimension.assessedAnswers;
    final countLabel = '$count assessed ${count == 1 ? 'answer' : 'answers'}';
    final percentage = feedbackPercentage(value);
    return Semantics(
      label: '${dimension.label} · $percentage · $countLabel',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: divider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.edge)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(dimension.label, style: palette.text())),
                const SizedBox(width: 10),
                if (MediaQuery.textScalerOf(palette.context).scale(1) <=
                    1.3) ...[
                  Flexible(
                    child: Text(
                      value < 50
                          ? 'Needs practice'
                          : value < 70
                          ? 'Developing'
                          : 'Strong',
                      style: palette.text(
                        size: 12.5,
                        weight: FontWeight.w500,
                        color: palette.score(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  percentage,
                  style: palette.number(color: palette.score(value)),
                ),
              ],
            ),
            if (showCount) Text(countLabel, style: palette.caption()),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: value / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(9),
              backgroundColor: palette.edge,
              color: palette.fill(value),
              stopIndicatorRadius: 0,
              trackGap: 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _coaching(BuildContext context, FeedbackPalette palette) {
    final findings = <String, List<String>>{};
    final actions = <String, List<String>>{};
    for (final finding in content.gaps) {
      (findings[finding.dimensionId] ??= []).add(finding.text);
    }
    for (final action in content.suggestions) {
      (actions[action.dimensionId] ??= []).add(action.text);
    }
    final dimensions = {for (final item in content.dimensions) item.id: item};
    final ids = {...findings.keys, ...actions.keys}.toList()
      ..sort((a, b) {
        final order = (dimensions[a]?.percentage ?? double.infinity).compareTo(
          dimensions[b]?.percentage ?? double.infinity,
        );
        return order == 0 ? a.compareTo(b) : order;
      });
    final complete = ids.where(practised.contains).length;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final query = searchQuery.trim().toLowerCase();
    final visibleIds = ids
        .where(
          (id) =>
              ('${dimensions[id]?.label} ${findings[id]?.join(' ')} ${actions[id]?.join(' ')}')
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final tiles = [
      for (final id in visibleIds)
        _practiceStep(
          palette,
          ids.indexOf(id),
          id,
          dimensions[id],
          findings[id] ?? const [],
          actions[id] ?? const [],
        ),
    ];

    return FeedbackPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FeedbackPanelHeader(
            'Your practice plan',
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (onPractised != null)
                  Text(
                    '$complete OF ${ids.length} PRACTISED',
                    style: palette.caption(),
                  ),
                const FeedbackBadge('COACHING'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: LayoutBuilder(
              builder: (context, bounds) {
                if (tiles.isEmpty) {
                  return Text(
                    'No tips match “$searchQuery”.',
                    style: palette.prose(),
                  );
                }
                const gap = 12.0;
                final viewport = MediaQuery.sizeOf(context).width;
                final columns =
                    viewport > 1250 && bounds.maxWidth >= 780 * scale
                    ? 3
                    : viewport > 760 && bounds.maxWidth >= 500 * scale
                    ? 2
                    : 1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var start = 0;
                      start < tiles.length;
                      start += columns
                    ) ...[
                      if (start > 0) const SizedBox(height: gap),
                      _alignedRow([
                        for (var i = start; i < start + columns; i++)
                          if (i < tiles.length)
                            tiles[i]
                          else
                            const SizedBox.shrink(),
                      ], gap: gap),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _practiceStep(
    FeedbackPalette palette,
    int index,
    String id,
    FeedbackDimension? dimension,
    List<String> findings,
    List<String> actions,
  ) {
    final checked = practised.contains(id);
    final onChanged = onPractised;
    return Ink(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: BoxDecoration(
        color: checked
            ? palette.soft.withAlpha(85)
            : palette.field.withAlpha(205),
        border: Border.all(color: palette.edge),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: palette.number(size: 14, color: palette.accent),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  dimension?.label ?? 'Practice suggestion',
                  style: palette.text(
                    size: 15,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              if (dimension != null) ...[
                const SizedBox(width: 6),
                Text(
                  feedbackPercentage(dimension.percentage),
                  style: palette.number(
                    color: palette.score(dimension.percentage),
                  ),
                ),
              ],
            ],
          ),
          for (final finding in findings) ...[
            const SizedBox(height: 6),
            Text(
              finding,
              style: palette.prose().copyWith(fontSize: 14, height: 1.5),
            ),
          ],
          for (final action in actions) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: palette.dark
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFEEF3FE), Color(0xFFF4F1FE)],
                      ),
                color: palette.dark ? palette.soft : null,
                border: Border.all(color: palette.accentEdge),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                action,
                semanticsLabel: 'Practice: $action',
                style: palette
                    .prose(color: palette.ink, weight: FontWeight.w500)
                    .copyWith(fontSize: 14, height: 1.5),
              ),
            ),
          ],
          if (onChanged != null)
            CheckboxListTile(
              value: checked,
              onChanged: (value) => onChanged(id, value ?? false),
              activeColor: FeedbackPalette.blue,
              checkColor: palette.field,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              horizontalTitleGap: 7,
              minLeadingWidth: 24,
              dense: true,
              visualDensity: VisualDensity.compact,
              checkboxScaleFactor: .8,
              minTileHeight: 40,
              title: Text('Mark as practised', style: palette.text(size: 13.5)),
            ),
        ],
      ),
    );
  }

  Widget _notes(
    FeedbackPalette palette,
    String title,
    Iterable<String> notes, {
    List<FeedbackQuestion>? questions,
  }) => FeedbackPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedbackPanelHeader(title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, note) in notes.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                Text(note, style: palette.prose()),
                if (questions != null)
                  Text(
                    '${questions[index].category} · ${feedbackPercentage(questions[index].percentage)}',
                    style: palette.caption(),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SkillRadar extends StatelessWidget {
  const _SkillRadar({required this.dimensions});

  final List<FeedbackDimension> dimensions;

  @override
  Widget build(BuildContext context) {
    final palette = FeedbackPalette(context);
    if (dimensions.length < 3) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'At least three assessed skills are needed for a radar chart.',
          textAlign: TextAlign.center,
          style: palette.caption(),
        ),
      );
    }
    return ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                (MediaQuery.sizeOf(context).height * .34).clamp(190.0, 330.0) *
                420 /
                410,
          ),
          child: AspectRatio(
            aspectRatio: 420 / 410,
            child: CustomPaint(
              painter: _RadarPainter(
                dimensions: dimensions,
                edge: palette.edge,
                labelStyle: palette.caption().copyWith(fontSize: 17),
                direction: Directionality.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.dimensions,
    required this.edge,
    required this.labelStyle,
    required this.direction,
  });

  final List<FeedbackDimension> dimensions;
  final Color edge;
  final TextStyle labelStyle;
  final TextDirection direction;
  static const _shortLabels = {
    'Reflection and collaboration': 'Reflection',
    'Specific examples': 'Examples',
    'Situational judgment': 'Judgment',
    'Situational reasoning': 'Situational reasoning',
    'Technical accuracy': 'Accuracy',
    'Technical reasoning': 'Technical reasoning',
  };
  static String shortLabel(String label) => _shortLabels[label] ?? label;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 420);
    canvas.translate(-30, 0);
    const center = Offset(240, 205);
    const radius = 118.0;
    Offset point(int i, double r) {
      final a = -math.pi / 2 + i * 2 * math.pi / dimensions.length;
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    Path polygon(double Function(int) r) {
      final path = Path()..moveTo(point(0, r(0)).dx, point(0, r(0)).dy);
      for (var i = 1; i < dimensions.length; i++) {
        final p = point(i, r(i));
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final line = Paint()..style = PaintingStyle.stroke;
    for (final (index, f) in [1.0, .75, .5, .25].indexed) {
      final ring = polygon((_) => radius * f);
      canvas.drawPath(
        ring,
        Paint()..color = index.isEven ? const Color(0xFFF6F8FB) : Colors.white,
      );
      canvas.drawPath(
        ring,
        line
          ..color = const Color(0xFFDDE4EB)
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < dimensions.length; i++) {
      canvas.drawLine(
        center,
        point(i, radius),
        line..color = const Color(0xFFE3E9EF),
      );
      final from = point(i, radius / 2),
          to = point((i + 1) % dimensions.length, radius / 2);
      final length = (to - from).distance;
      for (double d = 0; d < length; d += 9) {
        canvas.drawLine(
          Offset.lerp(from, to, d / length)!,
          Offset.lerp(from, to, math.min(d + 5, length) / length)!,
          line
            ..strokeWidth = 1.6
            ..color = FeedbackPalette.blue.withValues(alpha: .6),
        );
      }
    }
    void text(
      String value,
      Offset position,
      TextStyle style, {
      TextAlign align = TextAlign.left,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: direction,
        textAlign: align,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          position.dx -
              (align == TextAlign.center
                  ? painter.width / 2
                  : align == TextAlign.right
                  ? painter.width
                  : 0),
          position.dy,
        ),
      );
      painter.dispose();
    }

    for (final f in [.25, .5, .75, 1.0]) {
      text(
        '${(f * 100).round()}${f == 1 ? '%' : ''}',
        Offset(247, 205 - radius * f + 1),
        labelStyle.copyWith(
          fontSize: 13,
          color: const Color(0xFF667380),
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final shape = polygon((i) => radius * dimensions[i].percentage / 100);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x143E6FF0), Color(0x573E6FF0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      shape,
      line
        ..color = FeedbackPalette.blue
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );
    for (final (i, item) in dimensions.indexed) {
      final value = item.percentage;
      final fill = value < 50
          ? const Color(0xFFE9A83C)
          : value < 70
          ? FeedbackPalette.blue
          : const Color(0xFF14B584);
      final ink = value < 50
          ? const Color(0xFF9A6212)
          : value < 70
          ? const Color(0xFF2951C9)
          : const Color(0xFF0B7D59);
      canvas.drawCircle(
        point(i, radius * value / 100),
        6.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        point(i, radius * value / 100),
        6.5,
        line
          ..color = fill
          ..strokeWidth = 3.5,
      );
      if (dimensions.length > 10) continue;
      final position = point(i, radius + 24);
      final a = -math.pi / 2 + i * 2 * math.pi / dimensions.length;
      final align = math.cos(a) > .3
          ? TextAlign.left
          : math.cos(a) < -.3
          ? TextAlign.right
          : TextAlign.center;
      final lines = shortLabel(item.label).split(' ');
      final n = lines.length + 1;
      final y = math.sin(a) < -.5
          ? position.dy - (n - 1) * 19 - 4
          : math.sin(a) > .5
          ? position.dy + 15
          : position.dy - (n - 1) * 19 / 2 + 5;
      for (final (j, label) in [...lines, feedbackPercentage(value)].indexed) {
        text(
          label,
          Offset(position.dx, y + j * 19),
          labelStyle.copyWith(
            height: 1,
            color: j == lines.length ? ink : const Color(0xFF14202E),
            fontWeight: j == lines.length ? FontWeight.w800 : FontWeight.w600,
          ),
          align: align,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.dimensions != dimensions ||
      old.edge != edge ||
      old.labelStyle != labelStyle ||
      old.direction != direction;
}
