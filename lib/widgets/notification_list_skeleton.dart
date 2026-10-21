import 'package:flutter/material.dart';

/// Mirrors the notification list's card corners, row insets, and dividers.
class NotificationListSkeleton extends StatefulWidget {
  const NotificationListSkeleton({super.key, this.isMobile = false});

  final bool isMobile;

  @override
  State<NotificationListSkeleton> createState() =>
      _NotificationListSkeletonState();
}

class _NotificationListSkeletonState extends State<NotificationListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shape({required double height, double? width, bool circle = false}) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDF3),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.isMobile ? 16.0 : 20.0;
    final vertical = widget.isMobile ? 12.0 : 14.0;

    return Semantics(
      label: 'Loading notifications',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    vertical,
                    horizontal,
                    8,
                  ),
                  child: _shape(width: 48, height: 12),
                ),
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0)
                    const Divider(
                      color: Color(0xFFF1F5F9),
                      height: 1,
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontal,
                      vertical: vertical,
                    ),
                    child: Row(
                      children: [
                        _shape(width: 40, height: 40, circle: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final available = constraints.maxWidth;
                              final titleWidth =
                                  (available * (index == 1 ? 0.62 : 0.78))
                                      .clamp(0.0, index == 1 ? 280.0 : 360.0);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _shape(width: titleWidth, height: 14),
                                  const SizedBox(height: 8),
                                  _shape(
                                    width: (titleWidth * 0.42).clamp(
                                      0.0,
                                      120.0,
                                    ),
                                    height: 11,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
