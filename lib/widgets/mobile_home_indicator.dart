import 'package:flutter/material.dart';

/// Overlays one decorative home indicator without adding a footer background.
Widget mobileHomeIndicatorBuilder(BuildContext context, Widget? child) {
  if (child == null) return const SizedBox.shrink();
  if (MediaQuery.sizeOf(context).width >= 900) return child;

  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

  return Stack(
    children: [
      Positioned.fill(
        child: child,
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: bottomInset + 8,
        child: IgnorePointer(
          child: Align(
            heightFactor: 1,
            child: Container(
              key: const Key('mobile-home-indicator'),
              width: (MediaQuery.sizeOf(context).width * .30)
                  .clamp(130.0, 220.0)
                  .toDouble(),
              height: 5,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(127, 140, 170, 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
