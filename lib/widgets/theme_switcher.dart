import 'package:flutter/material.dart';

import '../services/app_theme_controller.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({
    super.key,
    required this.surface,
    required this.track,
    required this.border,
    required this.foreground,
    required this.inactiveForeground,
    required this.labelStyle,
    this.mobile = false,
    this.horizontalPadding = 9,
  });

  final Color surface;
  final Color track;
  final Color border;
  final Color foreground;
  final Color inactiveForeground;
  final TextStyle labelStyle;
  final bool mobile;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);
    final radius = BorderRadius.circular(mobile ? 8 : 6);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, label) in const [
            (ThemeMode.light, 'Light'),
            (ThemeMode.dark, 'Dark'),
            (ThemeMode.system, 'System'),
          ])
            Semantics(
              selected: controller.value == mode,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.select(mode),
                  borderRadius: radius,
                  child: Container(
                    height: mobile ? 34 : 28,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: controller.value == mode ? surface : null,
                      borderRadius: radius,
                      border: controller.value == mode
                          ? Border.all(color: border)
                          : null,
                    ),
                    child: Text(
                      label,
                      style: labelStyle.copyWith(
                        color: controller.value == mode
                            ? foreground
                            : inactiveForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
