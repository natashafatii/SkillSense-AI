import 'package:flutter/material.dart';

/// Primary action colors shared by recruiter screens. Other styling is retained.
class RecruiterButtonStyle {
  static const blue = Color(0xFF1A368A);
  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2F56C2), blue],
  );

  static ButtonStyle primary(ButtonStyle base, {bool active = true}) =>
      active ? _primary(base) : base;

  static ButtonStyle _primary(ButtonStyle base, {bool theme = false}) =>
      base.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? base.backgroundColor?.resolve(states)
              : Colors.transparent,
        ),
        backgroundBuilder: (context, states, child) {
          final widget = context.widget;
          final local = widget is ButtonStyleButton ? widget.style : null;
          if (states.contains(WidgetState.disabled) ||
              (theme && local?.backgroundColor?.resolve(states) != null)) {
            return base.backgroundBuilder?.call(context, states, child) ??
                child ??
                const SizedBox.shrink();
          }
          return DecoratedBox(
            decoration: ShapeDecoration(
              gradient: primaryGradient,
              shape:
                  local?.shape?.resolve(states) ??
                  base.shape?.resolve(states) ??
                  const StadiumBorder(),
            ),
            child: child,
          );
        },
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? base.foregroundColor?.resolve(states)
              : Colors.white,
        ),
      );

  static ThemeData theme(ThemeData base) => base.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _primary(
        base.elevatedButtonTheme.style ?? const ButtonStyle(),
        theme: true,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _primary(
        base.filledButtonTheme.style ?? const ButtonStyle(),
        theme: true,
      ),
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
