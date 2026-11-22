part of 'application_screening_screen.dart';

class _ScreeningOutcome extends StatelessWidget {
  const _ScreeningOutcome({
    required this.evidence,
    required this.score,
    required this.canDecide,
  });
  final ScreeningAssessment? evidence;
  final double? score;
  final bool canDecide;

  @override
  Widget build(BuildContext context) {
    final failed = evidence?.status == 'FAILED';
    final pending = evidence?.pending == true;
    final threshold = evidence?.threshold;
    final below = score != null && threshold != null && score! < threshold;
    final verified =
        evidence?.status == 'SUCCEEDED' &&
        evidence?.eligibility == 'PASS' &&
        !below;
    final missing = evidence?.missingSkills.length ?? 0;
    final (title, description) = switch ((
      failed,
      pending,
      verified,
      canDecide,
      below,
    )) {
      (true, _, _, _, _) => (
        'Screening could not complete',
        evidence!.errorMessage.isNotEmpty
            ? evidence!.errorMessage
            : 'Review the processing details for recovery guidance.',
      ),
      (_, true, _, _, _) => (
        'Screening in progress',
        'The resume is being assessed against this job’s requirements. Evidence will appear when processing finishes.',
      ),
      (_, _, true, _, _) => (
        'Screening criteria met',
        'The match score meets the policy threshold and all required criteria are verified.',
      ),
      (_, _, _, true, true) => (
        'Manual screening decision required',
        missing == 0
            ? 'The match score is below the screening threshold. Review the requirement evidence before recording a decision.'
            : missing == 1
            ? 'One skill is not evidenced in the extracted resume, and the match score is below the screening threshold.'
            : '${_screeningCount(missing)} skills are not evidenced in the extracted resume, and the match score is below the screening threshold.',
      ),
      (_, _, _, true, _) => (
        'Recruiter review needed',
        'Review the requirements and extracted resume evidence before recording a decision.',
      ),
      _ => (
        'Screening assessment',
        'Review the policy recommendation and requirement evidence below.',
      ),
    };
    final width = MediaQuery.sizeOf(context).width;
    final status = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: ScreeningStyle.soft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: failed
                  ? ScreeningStyle.red
                  : evidence == null || pending
                  ? _accent
                  : _green,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _copy(
              'Assessment ${pending ? 'processing' : _label(evidence?.status, 'pending').toLowerCase()}',
              size: 12,
              weight: 600,
            ),
          ),
        ],
      ),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: failed
                ? ScreeningStyle.rose
                : verified
                ? ScreeningStyle.mint
                : ScreeningStyle.review,
            borderRadius: BorderRadius.circular(11),
          ),
          child: ScreeningIcon(
            verified ? ScreeningGlyph.check : ScreeningGlyph.info,
            size: 18,
            color: failed
                ? ScreeningStyle.red
                : verified
                ? _green
                : _blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ScreeningStyle.title()),
              const SizedBox(height: 4),
              _copy(description, size: 13),
            ],
          ),
        ),
        if (width > 640) ...[const SizedBox(width: 12), status],
      ],
    );
    final scoreSize = width <= 640 ? 38.0 : 44.0;
    final value = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: score == null ? '—' : _number(score!),
                style: ScreeningStyle.text(
                  scoreSize,
                  weight: 800,
                  height: 1,
                  spacing: -.045 * scoreSize,
                ),
              ),
              TextSpan(
                text: '  / 100',
                style: ScreeningStyle.text(13, weight: 600, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _copy('Screening match', size: 12, weight: 600),
      ],
    );
    final gauge = _ScreeningGauge(score: score, threshold: threshold);
    return ScreeningPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: width <= 640 ? 20 : 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if (width <= 640) ...[const SizedBox(height: 12), status],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xfff5f8ff), ScreeningStyle.pale],
                ),
                border: Border.all(color: ScreeningStyle.tint),
                borderRadius: BorderRadius.circular(12),
              ),
              child: width <= 900
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [value, const SizedBox(height: 6), gauge],
                    )
                  : Row(
                      children: [
                        value,
                        const SizedBox(width: 28),
                        Expanded(child: gauge),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreeningGauge extends StatelessWidget {
  const _ScreeningGauge({required this.score, required this.threshold});
  final double? score, threshold;

  @override
  Widget build(BuildContext context) {
    final delta = score != null && threshold != null
        ? double.parse((score! - threshold!).toStringAsFixed(2))
        : null;
    final label = threshold == null
        ? 'Policy threshold unavailable'
        : 'Policy threshold · ${_number(threshold!)}';
    final note = switch (delta) {
      null => score == null ? 'Awaiting score' : '',
      < 0 => '${_number(delta.abs())} below threshold',
      0 => 'At threshold',
      _ => '+${_number(delta)} above threshold',
    };
    return Semantics(
      label:
          '${score == null ? 'Screening score unavailable' : 'Screening score ${_number(score!)} out of 100'}. $label. $note',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, size) {
              final marker =
                  (threshold ?? 0).clamp(0, 100) * size.maxWidth / 100;
              final scaled = MediaQuery.textScalerOf(context).scale(11);
              final tagWidth = (scaled * 9).clamp(
                92.0,
                size.maxWidth.clamp(92.0, double.infinity),
              );
              return SizedBox(
                height: 36 + (scaled - 11).clamp(0, 45),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 10,
                      child: CustomPaint(
                        painter: _GaugeTrack(score, threshold),
                      ),
                    ),
                    if (threshold != null) ...[
                      Positioned(
                        left: marker - 1.5,
                        bottom: -7,
                        width: 3,
                        height: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ScreeningStyle.ink,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (marker - tagWidth / 2).clamp(
                          0,
                          (size.maxWidth - tagWidth).clamp(0, double.infinity),
                        ),
                        bottom: 23,
                        width: tagWidth,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ScreeningStyle.ink,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Threshold ',
                                    style: ScreeningStyle.text(
                                      11,
                                      weight: 500,
                                      color: const Color(0xccffffff),
                                      height: 1.2,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _number(threshold!),
                                    style: ScreeningStyle.text(
                                      11,
                                      weight: 700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final tick in ['0', '25', '50', '75', '100'])
                _copy(
                  tick,
                  size: 11,
                  weight: 600,
                  color: const Color(0xff5b6a86),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, size) => Flex(
              direction: size.maxWidth < 260 ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _copy(label, size: 12, weight: 600),
                if (note.isNotEmpty)
                  _copy(
                    note,
                    size: 12,
                    weight: 700,
                    color: delta == null
                        ? _muted
                        : delta < 0
                        ? const Color(0xff334a7a)
                        : _green,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeTrack extends CustomPainter {
  const _GaugeTrack(this.score, this.threshold);
  final double? score, threshold;
  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(99),
    );
    canvas.drawRRect(track, Paint()..color = _line);
    if (score == null) return;
    final fill = size.width * score!.clamp(0, 100) / 100;
    final cut = size.width * (threshold ?? score!).clamp(0, 100) / 100;
    final fillRect = Rect.fromLTWH(0, 0, fill, size.height);
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(99)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xff7aa0ff), _accent],
          ).createShader(fillRect),
      );
    }
    if (cut == fill) return;
    final below = cut > fill;
    final start = below ? fill : cut;
    final end = below ? cut : fill;
    canvas.save();
    canvas.clipRRect(track);
    canvas.clipRect(Rect.fromLTRB(start, 0, end, size.height));
    if (below) canvas.drawColor(const Color(0xffc9d5ea), BlendMode.src);
    final stripe = Paint()
      ..strokeWidth = 4
      ..color = below ? const Color(0xff8fa3c8) : const Color(0x99ffffff);
    for (var x = start - size.height; x < end + size.height; x += 11.3) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GaugeTrack oldDelegate) =>
      oldDelegate.score != score || oldDelegate.threshold != threshold;
}
