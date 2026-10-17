import 'package:flutter/material.dart';

/// Adds one decorative home indicator below every mobile route.
Widget mobileHomeIndicatorBuilder(BuildContext context, Widget? child) {
  if (child == null) return const SizedBox.shrink();
  if (MediaQuery.sizeOf(context).width >= 900) return child;

  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

  return Stack(
    children: [
      Positioned.fill(
        bottom: bottomInset + 4,
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: bottomInset,
        child: IgnorePointer(
          child: Align(
            heightFactor: 1,
            child: Container(
              key: const Key('mobile-home-indicator'),
              width: 110,
              height: 4,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(127, 140, 170, 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
