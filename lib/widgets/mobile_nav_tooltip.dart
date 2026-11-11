import 'dart:async';
import 'package:flutter/material.dart';

/// A tap-only label that stays inside the dock's top edge, below its submenu.
class MobileNavTooltip extends StatefulWidget {
  const MobileNavTooltip({
    super.key,
    required this.message,
    required this.builder,
  });

  final String message;
  final Widget Function(VoidCallback show) builder;

  @override
  State<MobileNavTooltip> createState() => _MobileNavTooltipState();
}

class _MobileNavTooltipState extends State<MobileNavTooltip>
    with SingleTickerProviderStateMixin {
  static _MobileNavTooltipState? _current;
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _fade =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1780),
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _portal.hide();
            if (_current == this) _current = null;
          }
        });
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 120),
      // Keep the label fully visible for exactly 1.5 seconds.
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1500),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 160),
    ]).animate(_fade);
  }

  void _show() {
    if (_current != this) _current?._hideImmediately();
    _current = this;
    _timer?.cancel();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _portal.show();
    if (_reduceMotion) {
      _fade.stop();
      _timer = Timer(const Duration(milliseconds: 1500), _hideImmediately);
    } else {
      _fade.forward(from: 0);
    }
  }

  void _hideImmediately() {
    _timer?.cancel();
    _fade.stop();
    _portal.hide();
    if (_current == this) _current = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_current == this) _current = null;
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.topCenter,
                offset: const Offset(0, -4),
                child: FadeTransition(
                  key: const Key('mobile-nav-tooltip-fade'),
                  opacity: _reduceMotion
                      ? const AlwaysStoppedAnimation(1.0)
                      : _opacity,
                  child: Column(
                    key: const Key('mobile-nav-tooltip'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17233B),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const CustomPaint(
                        size: Size(8, 4),
                        painter: _TooltipArrow(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    child: CompositedTransformTarget(link: _link, child: widget.builder(_show)),
  );
}

class _TooltipArrow extends CustomPainter {
  const _TooltipArrow();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = const Color(0xFF17233B),
  );

  @override
  bool shouldRepaint(_TooltipArrow oldDelegate) => false;
}
