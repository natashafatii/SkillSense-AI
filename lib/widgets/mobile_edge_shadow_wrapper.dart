import 'package:flutter/material.dart';

/// Opt-in depth treatment for the main scroll viewport of authenticated pages.
/// Keep headers, navigation, dialogs and pre-authentication pages outside it.
class MobileEdgeShadowWrapper extends StatelessWidget {
  const MobileEdgeShadowWrapper({
    super.key,
    required this.child,
    this.surfaceColor,
  });

  final Widget child;

  /// Supports pages with a local palette independent of the app's ThemeData.
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900) return child;

    final dark = surfaceColor != null
        ? surfaceColor!.computeLuminance() < 0.2
        : Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Colors.white : const Color(0xFF0F172A);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 40,
          child: IgnorePointer(
            key: const Key('mobile-content-edge-shadow'),
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      tint.withValues(alpha: 0),
                      tint.withValues(alpha: dark ? 0.04 : 0.07),
                      tint.withValues(alpha: dark ? 0.12 : 0.22),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
