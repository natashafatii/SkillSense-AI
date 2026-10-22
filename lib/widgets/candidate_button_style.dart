import 'package:flutter/material.dart';

/// The candidate action palette, shared by the buttons on candidate screens.
class CandidateButtonStyle {
  static const Color teal = Color(0xFF14B584);
  static const Color deepTeal = Color(0xFF0A8A76);
  static const Color paleTeal = Color(0xFFE7F4F1);
  static const Color edge = Color(0xFFE2E8F0);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color error = Color(0xFFE85D5B);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, deepTeal],
  );

  /// Apply the reference green gradient without changing a button's geometry,
  /// text styling, or disabled appearance.
  static ButtonStyle primaryColors(ButtonStyle base) => base.copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? base.backgroundColor?.resolve(states)
          : Colors.transparent,
    ),
    backgroundBuilder: (context, states, child) {
      if (states.contains(WidgetState.disabled)) {
        return base.backgroundBuilder?.call(context, states, child) ??
            child ??
            const SizedBox.shrink();
      }
      return DecoratedBox(
        decoration: ShapeDecoration(
          gradient: primaryGradient,
          shape: base.shape?.resolve(states) ?? const StadiumBorder(),
        ),
        child: child,
      );
    },
  );

  static BoxDecoration primaryDecoration({double radius = 12}) => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: teal.withValues(alpha: .22),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );

  static ButtonStyle primary(ButtonStyle base, {double radius = 12}) =>
      base.merge(
        ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? secondaryText
                : Colors.white,
          ),
          shadowColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? Colors.transparent
                : teal.withValues(
                    alpha: states.contains(WidgetState.hovered) ? .4 : .22,
                  ),
          ),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? 0
                : (states.contains(WidgetState.hovered) ? 5 : 3),
          ),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: .08),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
          backgroundBuilder: (context, states, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: states.contains(WidgetState.disabled) ? edge : null,
              gradient: states.contains(WidgetState.disabled)
                  ? null
                  : primaryGradient,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: child,
          ),
        ),
      );

  static ButtonStyle secondary(ButtonStyle base, {double radius = 12}) =>
      base.merge(
        ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          foregroundColor: const WidgetStatePropertyAll(secondaryText),
          side: const WidgetStatePropertyAll(BorderSide(color: edge)),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStatePropertyAll(teal.withValues(alpha: .06)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
        ),
      );

  static ButtonStyle destructive(ButtonStyle base, {double radius = 12}) =>
      base.merge(
        ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(error.withValues(alpha: .08)),
          foregroundColor: const WidgetStatePropertyAll(error),
          side: WidgetStatePropertyAll(
            BorderSide(color: error.withValues(alpha: .4)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStatePropertyAll(error.withValues(alpha: .08)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
        ),
      );
}
