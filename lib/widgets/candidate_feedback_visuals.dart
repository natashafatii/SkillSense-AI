import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class FeedbackPalette {
  FeedbackPalette(this.context)
    : dark = Theme.of(context).brightness == Brightness.dark;

  final BuildContext context;
  final bool dark;
  static const teal = Color(0xFF0FB89B);
  static const blue = Color(0xFF3E6FF0);
  Color get canvas => dark ? const Color(0xFF101827) : const Color(0xFFF6F8FE);
  Color get panel => dark ? const Color(0xEB1B2639) : const Color(0xEBFFFFFF);
  Color get field => dark ? const Color(0xFF202D43) : Colors.white;
  Color get edge => dark ? const Color(0x2997ACC9) : const Color(0xFFDCE1EE);
  Color get ink => dark ? const Color(0xFFE9EFFA) : const Color(0xFF1B2740);
  Color get meta => dark ? const Color(0xFFBBC7DA) : const Color(0xFF4A5875);
  Color get soft => dark ? const Color(0xFF203254) : const Color(0xFFE3EBFE);
  Color get accent => dark ? const Color(0xFFA7BDFF) : const Color(0xFF2743A8);
  Color get accentEdge =>
      dark ? const Color(0xFF384F80) : const Color(0xFFC6D6FB);

  Color fill(double value) => switch (value) {
    >= 70 => const Color(0xFF14B584),
    >= 50 => blue,
    _ => const Color(0xFFE9A83C),
  };

  Color score(double value) => switch ((dark, value)) {
    (true, >= 70) => const Color(0xFF87DFC2),
    (true, >= 50) => const Color(0xFFA7BDFF),
    (true, _) => const Color(0xFFF6C477),
    (false, >= 70) => const Color(0xFF0B7D59),
    (false, >= 50) => const Color(0xFF2951C9),
    (false, _) => const Color(0xFF9A6212),
  };

  TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double height = 1.25,
  }) => TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [ui.FontVariation('wght', weight.value.toDouble())],
    color: color ?? ink,
    height: height,
  );

  TextStyle prose({Color? color, FontWeight weight = FontWeight.w400}) =>
      text(size: 14, weight: weight, height: 1.55, color: color ?? meta);

  TextStyle caption({bool uppercase = false}) => text(
    size: uppercase ? 12 : 13,
    weight: uppercase ? FontWeight.w600 : FontWeight.w500,
    color: meta,
    height: 1.4,
  ).copyWith(letterSpacing: uppercase ? .6 : 0);

  TextStyle number({double size = 14, Color? color, bool bold = false}) =>
      TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
        fontVariations: [ui.FontVariation('wght', bold ? 800 : 700)],
        color: color ?? ink,
        height: 1.2,
        letterSpacing: -size * .02,
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      );
}

String feedbackPercentage(double value) =>
    '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.child,
    this.highlighted = false,
  });

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = FeedbackPalette(context);
    final radius = BorderRadius.circular(18);
    return CustomPaint(
      painter: _PanelShadow(
        radius,
        dark: palette.dark,
        highlighted: highlighted,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: highlighted && !palette.dark
              ? const Color(0xEBFFFFFF)
              : palette.panel,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: palette.dark ? palette.edge : const Color(0xE6FFFFFF),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PanelShadow extends CustomPainter {
  const _PanelShadow(
    this.radius, {
    required this.dark,
    required this.highlighted,
  });

  final BorderRadius radius;
  final bool dark, highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shadow = highlighted
        ? const BoxShadow(
            color: Color(0x4D26334D),
            offset: Offset(0, 26),
            blurRadius: 54,
            spreadRadius: -26,
          )
        : const BoxShadow(
            color: Color(0x4D26334D),
            offset: Offset(0, 16),
            blurRadius: 38,
            spreadRadius: -26,
          );
    // Keep the outside shadow from showing through the translucent panel.
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds.inflate(96))
        ..addRRect(radius.toRRect(bounds)),
    );
    for (final layer in [
      shadow,
      BoxShadow(
        color: dark ? const Color(0x22000000) : const Color(0x0A26334D),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ]) {
      final rect = bounds.shift(layer.offset).inflate(layer.spreadRadius);
      if (!rect.isEmpty) {
        canvas.drawRRect(radius.toRRect(rect), layer.toPaint());
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanelShadow old) =>
      old.radius != radius ||
      old.dark != dark ||
      old.highlighted != highlighted;
}

class FeedbackPanelHeader extends StatelessWidget {
  const FeedbackPanelHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = FeedbackPalette(context);
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: palette.text(size: 16.5, weight: FontWeight.w700),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.edge)),
      ),
      child: Row(
        children: [
          Expanded(child: heading),
          if (trailing case final accessory?) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: accessory,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FeedbackBadge extends StatelessWidget {
  const FeedbackBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = FeedbackPalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.soft,
        border: Border.all(color: palette.accentEdge),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: palette
            .caption(uppercase: true)
            .copyWith(color: palette.accent, fontSize: 12, letterSpacing: .48),
      ),
    );
  }
}

class FeedbackRing extends StatelessWidget {
  const FeedbackRing({
    super.key,
    required this.size,
    required this.thickness,
    required this.value,
    required this.child,
  });

  final double size;
  final double thickness;
  final double? value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = FeedbackPalette(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value,
          thickness: thickness,
          fill: palette.fill(value ?? 0),
          track: palette.edge,
          core: palette.field,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(thickness + 3),
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.thickness,
    required this.fill,
    required this.track,
    required this.core,
  });

  final double? value;
  final double thickness;
  final Color fill, track, core;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()..color = core;
    canvas.drawCircle(center, radius, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - thickness / 2,
    );
    if (value == null) {
      const count = 14;
      for (var i = 0; i < count; i++) {
        canvas.drawArc(rect, i * 2 * math.pi / count, .25, false, paint);
      }
      return;
    }
    canvas.drawOval(rect, paint);
    paint.color = fill;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value! / 100,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.thickness != thickness ||
      old.fill != fill ||
      old.track != track ||
      old.core != core;
}

class FeedbackBackdrop extends StatelessWidget {
  const FeedbackBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: child,
    );
  }
}

/// Reference gauge uses a 140-unit dial with a 52-unit score ring.
class FeedbackGauge extends StatelessWidget {
  const FeedbackGauge({super.key, required this.size, required this.value});
  final double size;
  final double? value;
  @override
  Widget build(BuildContext context) {
    final p = FeedbackPalette(context);
    return Semantics(
      label:
          'Overall score ${value == null ? 'unavailable' : feedbackPercentage(value!)}',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _GaugePainter(value, p),
          child: Center(
            // Keep the entire label inside the dial's inner circle, rather
            // than fitting it against the full canvas (which includes ticks).
            child: SizedBox(
              width: size * .55,
              height: size * .36,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value == null
                          ? 'Unavailable'
                          : feedbackPercentage(value!),
                      style: p.number(
                        size: value == null
                            ? 15
                            : (MediaQuery.sizeOf(context).height * .037).clamp(
                                26.0,
                                36.0,
                              ),
                        bold: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('OVERALL', style: p.caption(uppercase: true)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.palette);
  final double? value;
  final FeedbackPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 140);
    const center = Offset(70, 70);
    final paint = Paint();
    for (var i = 0; i < 20; i++) {
      final big = i % 5 == 0;
      final angle = i * math.pi / 10;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + unit * (big ? 61 : 62.5),
        center + unit * (big ? 67 : 65.5),
        paint
          ..color = big ? const Color(0xFF9AA6B4) : const Color(0xFFCBD3DC)
          ..strokeWidth = big ? 1.6 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      center,
      45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.field,
            palette.dark ? palette.panel : const Color(0xFFF1F4F8),
          ],
        ).createShader(const Rect.fromLTWH(25, 25, 90, 90)),
    );
    const bounds = Rect.fromLTWH(18, 18, 104, 104);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..color = palette.dark ? palette.edge : const Color(0xFFEBEFF3);
    canvas.drawOval(bounds, paint);
    if (value != null) {
      final color = palette.fill(value!);
      final angle = value! * math.pi / 50;
      paint
        ..shader = LinearGradient(
          colors: [Color.lerp(color, Colors.white, .3)!, color],
        ).createShader(bounds)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(bounds, -math.pi / 2, angle, false, paint);
      final end =
          center +
          Offset(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2)) *
              52;
      canvas.drawCircle(end, 4.4, Paint()..color = palette.field);
      canvas.drawCircle(
        end,
        4.4,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.palette.dark != palette.dark;
}

class FeedbackScoreGuide extends StatelessWidget {
  const FeedbackScoreGuide({super.key});
  @override
  Widget build(BuildContext context) {
    final p = FeedbackPalette(context);
    return FeedbackPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FeedbackPanelHeader('Score guide'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Column(
              children: [
                for (final (value, range, label) in [
                  (0.0, 'Below 50%', 'Needs practice'),
                  (50.0, '50–69%', 'Developing'),
                  (70.0, '70% and up', 'Strong'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.fill(value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(range, style: p.text()),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            label,
                            style: p.text(
                              weight: FontWeight.w400,
                              color: p.meta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
