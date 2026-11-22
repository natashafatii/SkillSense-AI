part of 'application_screening_screen.dart';

class _RequirementEvidence extends StatefulWidget {
  const _RequirementEvidence({
    super.key,
    required this.criteria,
    required this.failed,
    required this.onResume,
  });
  final List<ScreeningCriterion> criteria;
  final bool failed;
  final VoidCallback onResume;
  @override
  State<_RequirementEvidence> createState() => _RequirementEvidenceState();
}

class _RequirementEvidenceState extends State<_RequirementEvidence> {
  static const _pageSize = 8;
  int _filter = 0, _page = 0;

  @override
  Widget build(BuildContext context) {
    final criteria = widget.criteria;
    final verified = criteria.where((row) => row.status == 'PASS').length;
    final matches = criteria
        .where(
          (row) => switch (_filter) {
            1 => row.status == 'PASS',
            2 => row.status != 'PASS',
            _ => true,
          },
        )
        .toList();
    final page = _page.clamp(
      0,
      matches.isEmpty ? 0 : (matches.length - 1) ~/ _pageSize,
    );
    final visible = matches.skip(page * _pageSize).take(_pageSize).toList();
    final side = ScreeningStyle.inset(context);
    return ScreeningPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreeningHeading(
            'Requirement evidence',
            criteria.isEmpty
                ? 'Requirement results are awaiting a completed assessment.'
                : '$verified of ${criteria.length} requirements verified from the extracted resume',
            action: ScreeningButton(
              'View resume details',
              kind: _link,
              onPressed: widget.onResume,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (criteria.isNotEmpty) ...[
                  Row(
                    children: [
                      if (verified > 0)
                        Expanded(flex: verified, child: _bar(_green)),
                      if (verified > 0 && verified < criteria.length)
                        const SizedBox(width: 3),
                      if (verified < criteria.length)
                        Expanded(
                          flex: criteria.length - verified,
                          child: _bar(const Color(0xffc9d5ea)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, size) {
                    final segment = Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: ScreeningStyle.soft,
                        border: Border.all(color: _line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Wrap(
                        spacing: 2,
                        children: [
                          for (final (index, label) in [
                            'All',
                            'Verified',
                            'Needs review',
                          ].indexed)
                            Semantics(
                              selected: _filter == index,
                              child: TextButton(
                                onPressed: criteria.isEmpty
                                    ? null
                                    : () => setState(() {
                                        _filter = index;
                                        _page = 0;
                                      }),
                                style: TextButton.styleFrom(
                                  foregroundColor: _filter == index
                                      ? _blue
                                      : _muted,
                                  backgroundColor: _filter == index
                                      ? Colors.white
                                      : Colors.transparent,
                                  minimumSize: const Size(0, 28),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  elevation: _filter == index ? 1 : 0,
                                  shadowColor: const Color(0x2426334d),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: ScreeningStyle.text(
                                    context,
                                    AppType.button,
                                  ),
                                ),
                                child: Text(label),
                              ),
                            ),
                        ],
                      ),
                    );
                    final count = _copy(
                      context,
                      '${criteria.length} requirements',
                      type: AppType.caption,
                    );
                    if (size.maxWidth < 390) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [segment, if (criteria.isNotEmpty) count],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [segment, if (criteria.isNotEmpty) count],
                    );
                  },
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 26,
                    ),
                    child: Column(
                      children: [
                        Text(
                          criteria.isEmpty
                              ? 'Evidence is not available yet'
                              : 'No requirements in this view',
                          style: ScreeningStyle.title(context, AppType.h4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          criteria.isNotEmpty
                              ? 'Choose another filter to see the recorded requirements.'
                              : widget.failed
                              ? 'Review the processing details for recovery guidance.'
                              : 'Refresh the application to check for completed screening.',
                          style: ScreeningStyle.text(
                            context,
                            AppType.bodySm,
                            color: _muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, size) {
                      final columns = ((size.maxWidth + 10) / 250)
                          .floor()
                          .clamp(1, criteria.length);
                      final width =
                          (size.maxWidth - (columns - 1) * 10) / columns;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var start = 0;
                            start < visible.length;
                            start += columns
                          ) ...[
                            if (start > 0) const SizedBox(height: 10),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var index = start;
                                    index < visible.length &&
                                        index < start + columns;
                                    index++
                                  ) ...[
                                    if (index > start)
                                      const SizedBox(width: 10),
                                    SizedBox(
                                      width: width,
                                      child: _RequirementCard(visible[index]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                if (matches.length > _pageSize) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ScreeningButton(
                        'Previous',
                        onPressed: page == 0
                            ? null
                            : () => setState(() => _page = page - 1),
                      ),
                      Flexible(
                        child: Semantics(
                          liveRegion: true,
                          child: _copy(
                            context,
                            '${page * _pageSize + 1}–${page * _pageSize + visible.length} of ${matches.length}',
                            type: AppType.caption,
                          ),
                        ),
                      ),
                      ScreeningButton(
                        'Next',
                        onPressed: (page + 1) * _pageSize >= matches.length
                            ? null
                            : () => setState(() => _page = page + 1),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(Color color) => Container(
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard(this.criterion);
  final ScreeningCriterion criterion;
  @override
  Widget build(BuildContext context) {
    final ok = criterion.status == 'PASS';
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? ScreeningStyle.mint : ScreeningStyle.review,
            ),
            child: ScreeningIcon(
              ok ? ScreeningGlyph.check : ScreeningGlyph.info,
              color: ok ? _green : _accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _copy(
                  context,
                  criterion.requirement,
                  color: ScreeningStyle.ink,
                  type: AppType.caption,
                ),
                _copy(
                  context,
                  criterion.evidence.trim().isEmpty
                      ? 'No evidence found in the resume'
                      : 'Resume evidence: “${criterion.evidence}”',
                  type: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (ok)
            _copy(context, 'Verified', color: _green, type: AppType.caption)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: ScreeningStyle.review,
                borderRadius: BorderRadius.circular(99),
              ),
              child: _copy(context, 'Needs review', type: AppType.caption),
            ),
        ],
      ),
    );
    if (!ok) return _DashedCard(radius: 12, child: body);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }
}

class _DashedCard extends StatelessWidget {
  const _DashedCard({required this.radius, required this.child});
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashBorder(radius),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: ScreeningStyle.canvas,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(padding: const EdgeInsets.all(1), child: child),
    ),
  );
}

class _DashBorder extends CustomPainter {
  const _DashBorder(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = ScreeningStyle.reviewLine
      ..style = PaintingStyle.stroke;
    for (final metric in outline.computeMetrics()) {
      for (var i = 0.0; i < metric.length; i += 7) {
        canvas.drawPath(
          metric.extractPath(i, (i + 4).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashBorder oldDelegate) => oldDelegate.radius != radius;
}

class _ScreeningHistory extends StatelessWidget {
  const _ScreeningHistory({
    super.key,
    required this.app,
    required this.assessment,
  });
  final Application app;
  final ScreeningAssessment? assessment;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final event in app.history)
        (
          '${_label(event['from_status'])} → ${_label(event['to_status'])}',
          '${event['reason'] ?? ''}',
          [
            _label(event['source']),
            if (DateTime.tryParse('${event['created_at']}') case final date?)
              _date(date),
          ].join(' · '),
        ),
      if (assessment?.completedAt case final completed?
          when !app.history.any(
            (event) => event['assessment_id'] == assessment!.id,
          ))
        (
          assessment!.status == 'FAILED'
              ? 'Screening could not complete'
              : 'Screening assessment completed',
          assessment!.errorMessage.isNotEmpty
              ? assessment!.errorMessage
              : _label(assessment!.outcome),
          'System · ${_date(completed)}',
        ),
      (
        'Application received',
        app.resumeId == null
            ? 'Application submitted for ${app.jobTitle}.'
            : 'A resume was submitted for ${app.jobTitle}.',
        _date(app.createdAt),
      ),
    ];
    final side = ScreeningStyle.inset(context);
    return ScreeningPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreeningHeading(
            'Screening history',
            'How this application reached its current stage',
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(side, 2, side, 16),
            child: Column(
              children: [
                for (final (index, (title, reason, metadata))
                    in entries.indexed)
                  Stack(
                    children: [
                      if (index < entries.length - 1)
                        const Positioned(
                          left: 5,
                          top: 20,
                          bottom: 2,
                          child: SizedBox(
                            width: 2,
                            child: ColoredBox(color: _line),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        top: 5,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == 0 ? _accent : Colors.white,
                            border: Border.all(
                              color: index == 0
                                  ? _accent
                                  : const Color(0xffc2cce0),
                              width: 2,
                            ),
                            boxShadow: index == 0
                                ? const [
                                    BoxShadow(
                                      color: Color(0x293e6ff0),
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 24,
                          bottom: index < entries.length - 1 ? 16 : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _copy(
                              context,
                              title,
                              color: ScreeningStyle.ink,
                              type: AppType.caption,
                            ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              _copy(context, reason, type: AppType.caption),
                            ],
                            const SizedBox(height: 6),
                            _copy(
                              context,
                              metadata,
                              color: const Color(0xff5b6a86),
                              type: AppType.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
