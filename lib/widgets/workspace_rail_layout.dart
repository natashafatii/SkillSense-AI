import 'package:flutter/material.dart';

/// Animates the rail edge without resizing the page on every frame.
class WorkspaceRailLayout extends StatefulWidget {
  static const collapsedWidth = 60.0;

  final bool expanded;
  final double expandedWidth;
  final Color railColor;
  final Color railBorderColor;
  final Widget rail;
  final Widget body;

  const WorkspaceRailLayout({
    super.key,
    required this.expanded,
    required this.expandedWidth,
    required this.railColor,
    required this.railBorderColor,
    required this.rail,
    required this.body,
  });

  @override
  State<WorkspaceRailLayout> createState() => _WorkspaceRailLayoutState();
}

class _WorkspaceRailLayoutState extends State<WorkspaceRailLayout> {
  late bool _settledExpanded = widget.expanded;

  @override
  void didUpdateWidget(covariant WorkspaceRailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _settledExpanded = false;
  }

  @override
  Widget build(BuildContext context) {
    const collapsed = WorkspaceRailLayout.collapsedWidth;
    final railWidth = widget.expanded ? widget.expandedWidth : collapsed;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) _settledExpanded = widget.expanded;
    // Keep the wider page during motion and move it at paint time. The page
    // reflows once, as the rail starts closing or finishes opening.
    final pageInset = _settledExpanded ? railWidth : collapsed;
    final rail = RepaintBoundary(child: widget.rail);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.expanded ? 1.0 : 0.0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      onEnd: () {
        if (widget.expanded && !_settledExpanded) {
          setState(() => _settledExpanded = true);
        }
      },
      child: RepaintBoundary(child: widget.body),
      builder: (context, progress, body) {
        final width = reduceMotion
            ? railWidth
            : collapsed + (widget.expandedWidth - collapsed) * progress;
        return ClipRect(
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              Positioned.fill(
                left: pageInset,
                child: Transform.translate(
                  offset: Offset(width - pageInset, 0),
                  child: body,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: widget.railBorderColor),
                    ),
                  ),
                  position: DecorationPosition.foreground,
                  child: ColoredBox(
                    color: widget.railColor,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: railWidth - 1,
                        maxWidth: railWidth - 1,
                        child: rail,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
