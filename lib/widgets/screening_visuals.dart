import 'package:skillsense_ai/theme/app_typography.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_svg/flutter_svg.dart';

import 'notification_unread_scope.dart';

abstract final class ScreeningStyle {
  static const ink = Color(0xff0f172a);
  static const muted = Color(0xff475569);
  static const line = Color(0xffe2e8f0);
  static const canvas = Color(0xfff8fafc);
  static const soft = Color(0xfff1f5f9);
  static const blue = Color(0xff2f56c2);
  static const navy = Color(0xff1a368a);
  static const accent = Color(0xff3e6ff0);
  static const tint = Color(0xffdeeaff);
  static const pale = Color(0xffeff3ff);
  static const green = Color(0xff0e8f76);
  static const mint = Color(0xffddf3ee);
  static const review = Color(0xffeaf0fb);
  static const reviewLine = Color(0xffbfcde8);
  static const red = Color(0xffc8374d);
  static const rose = Color(0xfffbe9ec);

  static double gutter(double width) => (width * .02).clamp(14, 32);
  static double inset(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= 640 ? 14 : 20;

  static TextStyle text(
    BuildContext context,
    AppType type, {
    Color color = ink,
  }) => type.style(context, color: color);

  static TextStyle title(BuildContext context, [AppType type = AppType.h3]) =>
      text(context, type);

  static InputDecoration field(BuildContext context, {String? hint}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: text(context, AppType.caption, color: muted),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
      );
}

enum ScreeningGlyph {
  check('<path d="m5 12 4 4L19 6"/>'),
  chevron('<path d="m6 9 6 6 6-6"/>'),
  back('<path d="m14 6-6 6 6 6M8 12h12"/>'),
  file('<path d="M6 3h8l4 4v14H6zM14 3v5h4m-9 4h6m-6 4h6"/>'),
  refresh('<path d="M20 10a8 8 0 1 0-1 8M20 4v6h-6"/>'),
  edit('<path d="m16 3 5 5L9 20l-6 1 1-6Z m-2 2 5 5"/>'),
  delete('<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15m-8 4v7m4-7v7"/>'),
  up('<path d="M12 20V4m-6 6 6-6 6 6"/>'),
  down('<path d="M12 4v16m-6-6 6 6 6-6"/>'),
  info('<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.1"/>'),
  search('<circle cx="10" cy="10" r="6"/><path d="m15 15 5 5"/>'),
  bell('<path d="M6 17h12l-1-3V9a5 5 0 0 0-10 0v5Zm4 3h4M12 2v2"/>');

  const ScreeningGlyph(this.path);
  final String path;
}

class ScreeningIcon extends StatelessWidget {
  const ScreeningIcon(this.glyph, {super.key, this.size = 16, this.color});
  final ScreeningGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final path = glyph.path;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<g fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" '
      'stroke-linejoin="round">$path</g></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? ScreeningStyle.ink,
        BlendMode.srcIn,
      ),
    );
  }
}

class ScreeningPanel extends StatelessWidget {
  const ScreeningPanel({super.key, required this.child, this.tint = false});
  final Widget child;
  final bool tint;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _PanelShadow(),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint ? null : const Color(0xf2ffffff),
        gradient: tint
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ScreeningStyle.pale, Colors.white],
                stops: [0, .55],
              )
            : null,
        border: Border.all(
          color: tint ? ScreeningStyle.tint : const Color(0xbfdce1ee),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        textStyle: DefaultTextStyle.of(context).style,
        child: child,
      ),
    ),
  );
}

class _PanelShadow extends CustomPainter {
  const _PanelShadow();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final edge = Path()
      ..addRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(14)));
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds.inflate(64)),
      edge,
    );
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.shift(const Offset(0, 2)),
        const Radius.circular(14),
      ),
      Paint()
        ..color = const Color(0x0a26334d)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    if (size.shortestSide > 52) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds.deflate(26).shift(const Offset(0, 16)),
          Radius.zero,
        ),
        Paint()
          ..color = const Color(0x5226334d)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 19),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanelShadow oldDelegate) => false;
}

class ScreeningHeading extends StatelessWidget {
  const ScreeningHeading(this.title, this.caption, {super.key, this.action});
  final String title;
  final String caption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final side = ScreeningStyle.inset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 15, side, 10),
      child: LayoutBuilder(
        builder: (context, size) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ScreeningStyle.title(context)),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: ScreeningStyle.text(
                    context,
                    AppType.caption,
                    color: ScreeningStyle.muted,
                  ),
                ),
              ],
            ],
          );
          if (action == null) return heading;
          if (size.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 6), action!],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 12),
              action!,
            ],
          );
        },
      ),
    );
  }
}

enum ScreeningButtonKind { normal, primary, danger, link }

class ScreeningButton extends StatelessWidget {
  const ScreeningButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = ScreeningButtonKind.normal,
    this.glyph,
    this.stretch = false,
    this.leftAligned = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final ScreeningButtonKind kind;
  final ScreeningGlyph? glyph;
  final bool stretch;
  final bool leftAligned;

  @override
  Widget build(BuildContext context) {
    final primary = kind == ScreeningButtonKind.primary;
    final link = kind == ScreeningButtonKind.link;
    final danger = kind == ScreeningButtonKind.danger;
    final color = switch (kind) {
      ScreeningButtonKind.primary => Colors.white,
      ScreeningButtonKind.link => ScreeningStyle.blue,
      ScreeningButtonKind.danger => ScreeningStyle.red,
      _ => ScreeningStyle.ink,
    };
    final radius = BorderRadius.circular(10);
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: SizedBox(
        width: stretch ? double.infinity : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: link || primary ? null : Colors.white,
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ScreeningStyle.blue, ScreeningStyle.navy],
                  )
                : null,
            border: link
                ? null
                : Border.all(
                    color: primary
                        ? ScreeningStyle.navy
                        : danger
                        ? const Color(0xfff1c4cb)
                        : ScreeningStyle.line,
                  ),
            borderRadius: radius,
            boxShadow: link
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0d26334d),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: color,
              disabledForegroundColor: color,
              overlayColor: primary ? Colors.white : ScreeningStyle.accent,
              alignment: link || leftAligned
                  ? Alignment.centerLeft
                  : Alignment.center,
              minimumSize: Size(0, link ? 26 : 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              padding: EdgeInsets.symmetric(
                horizontal: link ? 0 : 13,
                vertical: 3,
              ),
              shape: RoundedRectangleBorder(borderRadius: radius),
              textStyle: ScreeningStyle.text(
                context,
                AppType.button,
                color: color,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (glyph != null) ...[
                  ScreeningIcon(glyph!, color: color),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: link || leftAligned
                        ? TextAlign.start
                        : TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showScreeningDialog(
  BuildContext context, {
  required String title,
  required Widget child,
}) => showDialog<void>(
  context: context,
  barrierColor: const Color(0x800b1730),
  builder: (context) => ScreeningDialog(title: title, child: child),
);

class ScreeningDialog extends StatelessWidget {
  const ScreeningDialog({
    super.key,
    required this.title,
    required this.child,
    this.canClose = true,
  });
  final String title;
  final Widget child;
  final bool canClose;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: ScreeningStyle.line),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 580,
        maxHeight: MediaQuery.sizeOf(context).height * .87,
      ),
      child: DefaultTextStyle(
        style: ScreeningStyle.text(
          context,
          AppType.caption,
          color: ScreeningStyle.muted,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: ScreeningStyle.title(context, AppType.h4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ScreeningButton(
                    'Close',
                    onPressed: canClose
                        ? () => Navigator.of(context).pop()
                        : null,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ScreeningStyle.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _muted = ScreeningStyle.muted;
const _line = ScreeningStyle.line;

class ScreeningCommandBar extends StatelessWidget {
  const ScreeningCommandBar({
    super.key,
    required this.onSearch,
    required this.section,
  });
  final String section;
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => NotificationUnreadScope(
    builder: (context, unread) {
      final width = MediaQuery.sizeOf(context).width;
      final compact = width <= 640;
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xd1ffffff),
          border: Border(bottom: BorderSide(color: Color(0xe6dce1ee))),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 49),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (width * .02).clamp(14, 28),
              vertical: 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        'WORKSPACE',
                        style: ScreeningStyle.text(
                          context,
                          AppType.overline,
                          color: _muted,
                        ),
                      ),
                      Text(
                        '/',
                        style: ScreeningStyle.text(
                          context,
                          AppType.caption,
                          color: _muted,
                        ),
                      ),
                      Text(
                        section.toUpperCase(),
                        style: ScreeningStyle.text(context, AppType.overline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _button(
                  'Search or jump to a section',
                  compact ? 40 : 260,
                  onSearch,
                  Padding(
                    padding: EdgeInsets.only(
                      left: compact ? 0 : 12,
                      right: compact ? 0 : 10,
                    ),
                    child: Row(
                      mainAxisAlignment: compact
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        const ScreeningIcon(
                          ScreeningGlyph.search,
                          color: _muted,
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search or jump to...',
                              style: ScreeningStyle.text(
                                context,
                                AppType.caption,
                                color: _muted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ScreeningStyle.soft,
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⌘K',
                              style: ScreeningStyle.text(
                                context,
                                AppType.caption,
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _button(
                  'Notifications',
                  34,
                  () => Navigator.of(
                    context,
                  ).pushNamed('/recruiter/notifications'),
                  SizedBox.expand(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const ScreeningIcon(ScreeningGlyph.bell, color: _muted),
                        if (unread > 0)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: ScreeningStyle.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _button(String label, double width, VoidCallback tap, Widget child) =>
      Tooltip(
        message: label,
        child: SizedBox(
          width: width,
          height: 34,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: tap, child: child),
          ),
        ),
      );
}

class ScreeningBackground extends CustomPainter {
  const ScreeningBackground();
  @override
  void paint(Canvas canvas, Size size) {
    void glow(double x, double y, double rx, double ry, Color color) {
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.scale(rx * size.width, ry * size.height);
      canvas.drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, 1, [
            color,
            color.withAlpha(0),
          ]),
      );
      canvas.restore();
    }

    glow(.60, 1.12, .30, .216, const Color(0x172e63f0));
    glow(-.06, .46, .216, .18, const Color(0x143e6ff0));
    glow(.82, -.08, .299, .221, const Color(0x292e63f0));
  }

  @override
  bool shouldRepaint(ScreeningBackground oldDelegate) => false;
}

/// Keeps the desktop aside in view within its two-column section.
class ScreeningStickyAside extends StatelessWidget {
  const ScreeningStickyAside({
    super.key,
    required this.section,
    required this.child,
  });
  final GlobalKey section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;

    return AnimatedBuilder(
      animation: position,
      child: child,
      builder: (context, child) {
        final bounds = section.currentContext?.findRenderObject();
        final aside = context.findRenderObject();
        if (bounds is! RenderBox ||
            !bounds.hasSize ||
            aside is! RenderBox ||
            !aside.hasSize ||
            !position.hasPixels) {
          return Transform.translate(offset: Offset.zero, child: child);
        }
        final viewport = RenderAbstractViewport.maybeOf(bounds);
        final maxShift = (bounds.size.height - aside.size.height).clamp(
          0.0,
          double.infinity,
        );
        final top = viewport?.getOffsetToReveal(bounds, 0).offset;
        final offset = top == null
            ? 0.0
            : (position.pixels - top + 16).clamp(0.0, maxShift);
        return Transform.translate(offset: Offset(0, offset), child: child);
      },
    );
  }
}

Future<void> showScreeningSearch(
  BuildContext context,
  Map<String, VoidCallback> sections,
) => showScreeningDialog(
  context,
  title: 'Search or jump to',
  child: _ScreeningSectionSearch(sections),
);

class _ScreeningSectionSearch extends StatefulWidget {
  const _ScreeningSectionSearch(this.sections);
  final Map<String, VoidCallback> sections;

  @override
  State<_ScreeningSectionSearch> createState() =>
      _ScreeningSectionSearchState();
}

class _ScreeningSectionSearchState extends State<_ScreeningSectionSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.sections.entries.where(
      (item) => item.key.toLowerCase().contains(_query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Find a section',
          style: ScreeningStyle.text(context, AppType.caption),
        ),
        const SizedBox(height: 6),
        TextField(
          autofocus: true,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          textInputAction: TextInputAction.search,
          style: ScreeningStyle.text(context, AppType.body),
          decoration: ScreeningStyle.field(
            context,
            hint: 'Search this application',
          ),
        ),
        if (matches.isEmpty) ...[
          const SizedBox(height: 8),
          const Text('No matching sections.'),
        ],
        for (final item in matches) ...[
          const SizedBox(height: 8),
          ScreeningButton(
            item.key,
            leftAligned: true,
            onPressed: () {
              Navigator.of(context).pop();
              item.value();
            },
          ),
        ],
      ],
    );
  }
}
