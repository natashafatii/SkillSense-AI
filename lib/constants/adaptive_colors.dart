import 'package:flutter/material.dart';

import '../screens/admin/aurora_tokens.dart';

/// Resolves the light palette's surface and foreground roles against the
/// active Aurora palette. Explicit colors on branded fills and media can
/// retain their original contrast in both modes.
extension AdaptiveColors on BuildContext {
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  Color themeCanvas(Color light) =>
      isDarkTheme ? AuroraTokens.auroraNight.bg : light;

  Color themeSurface(Color light) {
    if (!isDarkTheme) return light;
    final tint = HSLColor.fromColor(light);
    final base = AuroraTokens.auroraNight.knob;
    final dark = tint.saturation < .13
        ? base
        : Color.alphaBlend(
            tint.withLightness(.48).withAlpha(.14).toColor(),
            base,
          );
    return dark.withValues(alpha: light.a);
  }

  Color themeOutline(Color light) => isDarkTheme
      ? AuroraTokens.auroraNight.edge.withValues(alpha: .42 * light.a)
      : light;

  Color themeChartTrack(Color light) =>
      isDarkTheme ? const Color(0xFF303A50) : light;

  Color themeOnFill(Color light, Color fill) =>
      isDarkTheme && fill.computeLuminance() > .179 ? Colors.black : light;

  Color themeForeground(Color light) {
    if (!isDarkTheme) return light;
    final tint = HSLColor.fromColor(light);
    final tokens = AuroraTokens.auroraNight;
    final color = tint.saturation >= .30 && tint.lightness >= .22
        ? tint.withLightness(.76).toColor()
        : switch (light.computeLuminance()) {
            < .09 => tokens.tx,
            < .26 => tokens.tx2,
            _ => tokens.tx3,
          };
    return color;
  }
}
