import 'package:flutter/material.dart';

/// Primary action colors shared by recruiter screens. Other styling is retained.
class RecruiterButtonStyle {
  static const blue = Color(0xFF1A368A);

  static ButtonStyle primary(ButtonStyle base) => base.copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? base.backgroundColor?.resolve(states)
          : blue,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? base.foregroundColor?.resolve(states)
          : Colors.white,
    ),
  );

  static ThemeData theme(ThemeData base) => base.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primary(base.elevatedButtonTheme.style ?? const ButtonStyle()),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: primary(base.filledButtonTheme.style ?? const ButtonStyle()),
    ),
  );
}

class RecruiterButtonTheme extends StatelessWidget {
  final Widget child;
  const RecruiterButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: RecruiterButtonStyle.theme(Theme.of(context)), child: child);
}
