import 'package:flutter/material.dart';

/// Preserves the page content without adding a mobile edge overlay.
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
  Widget build(BuildContext context) => child;
}
