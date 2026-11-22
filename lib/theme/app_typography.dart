import 'package:flutter/material.dart';

enum TypeStep { mobile, laptop, wide, xl }

TypeStep typeStepFor(double width) {
  if (width < 600) return TypeStep.mobile;
  if (width < 1600) return TypeStep.laptop;
  if (width < 2200) return TypeStep.wide;
  return TypeStep.xl;
}

abstract final class TypographyColors {
  static const primary = Color(0xFF0F172A);
  static const secondary = Color(0xFF475569);
  static const tertiary = Color(0xFF64748B);
  static const disabled = Color(0xFF94A3B8);
  static const recruiterAccent = Color(0xFF1D4ED8);
  static const candidateAccent = Color(0xFF0F766E);
}

enum AppType {
  display([30, 36, 40, 44], [38, 44, 48, 52], FontWeight.w700, tracking: -.020),
  h1([24, 28, 30, 34], [32, 36, 38, 42], FontWeight.w600, tracking: -.015),
  h2([20, 22, 24, 26], [28, 30, 32, 34], FontWeight.w600, tracking: -.010),
  h3([17, 18, 19, 21], [24, 26, 28, 30], FontWeight.w600, tracking: -.005),
  h4([15, 16, 17, 18], [22, 24, 24, 26], FontWeight.w600),
  bodyLg([16, 16, 17, 18], [26, 26, 27, 28], FontWeight.w400),
  body([15, 15, 16, 17], [24, 24, 25, 26], FontWeight.w400),
  bodySm([14, 14, 15, 16], [20, 20, 22, 23], FontWeight.w400),
  caption([13, 13, 14, 15], [18, 18, 20, 21], FontWeight.w500, tracking: .005),
  badge([13, 13, 13, 13], [18, 18, 18, 18], FontWeight.w600, tracking: .06),
  overline([12, 12, 13, 13], [16, 16, 18, 18], FontWeight.w600, tracking: .06),
  button([14, 14, 15, 16], [20, 20, 20, 22], FontWeight.w600),
  nav([14, 14, 15, 16], [20, 20, 22, 22], FontWeight.w500),
  metric(
    [28, 32, 36, 40],
    [32, 36, 40, 44],
    FontWeight.w600,
    tracking: -.015,
    tabular: true,
  ),
  numeric([14, 14, 15, 16], [20, 20, 22, 23], FontWeight.w500, tabular: true);

  const AppType(
    this.sizes,
    this.lines,
    this.weight, {
    this.tracking = 0,
    this.tabular = false,
  });

  final List<double> sizes;
  final List<double> lines;
  final FontWeight weight;
  final double tracking;
  final bool tabular;

  TextStyle style(BuildContext context, {Color? color, FontWeight? weight}) =>
      at(context.typeStep, color: color, weight: weight);

  TextStyle at(TypeStep step, {Color? color, FontWeight? weight}) {
    final size = sizes[step.index];
    final resolvedWeight = weight ?? this.weight;
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: resolvedWeight,
      height: lines[step.index] / size,
      letterSpacing: tracking * size,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      fontVariations: [
        FontVariation('wght', resolvedWeight.value.toDouble()),
        FontVariation('opsz', size.clamp(14.0, 32.0)),
      ],
    );
  }
}

TextTheme appTextTheme(TypeStep step, Color color) {
  TextStyle style(AppType token) => token.at(step, color: color);
  return TextTheme(
    displayLarge: style(AppType.display),
    displayMedium: style(AppType.display),
    displaySmall: style(AppType.h1),
    headlineLarge: style(AppType.h1),
    headlineMedium: style(AppType.h2),
    headlineSmall: style(AppType.h3),
    titleLarge: style(AppType.h3),
    titleMedium: style(AppType.h4),
    titleSmall: style(AppType.nav),
    bodyLarge: style(AppType.bodyLg),
    bodyMedium: style(AppType.body),
    bodySmall: style(AppType.bodySm),
    labelLarge: style(AppType.button),
    labelMedium: style(AppType.caption),
    labelSmall: style(AppType.overline),
  );
}

extension AppText on BuildContext {
  TypeStep get typeStep => typeStepFor(MediaQuery.sizeOf(this).width);
  TextTheme get text => Theme.of(this).textTheme;

  Color get primaryTextColor => Theme.of(this).brightness == Brightness.dark
      ? Theme.of(this).colorScheme.onSurface
      : TypographyColors.primary;

  Color get secondaryTextColor => Theme.of(this).brightness == Brightness.dark
      ? Theme.of(this).colorScheme.onSurfaceVariant
      : TypographyColors.secondary;

  TextStyle get secondaryBody =>
      AppType.bodySm.style(this, color: secondaryTextColor);
  TextStyle get secondaryCaption =>
      AppType.caption.style(this, color: secondaryTextColor);

  double get sidebarWidth => typeStep.index >= TypeStep.wide.index ? 288 : 272;

  double get twoLineRowHeight => switch (typeStep) {
    TypeStep.mobile || TypeStep.laptop => 60,
    TypeStep.wide => 68,
    TypeStep.xl => 76,
  };

  double get controlHeight => typeStep == TypeStep.mobile ? 48 : 40;

  double get cardPadding => typeStep.index >= TypeStep.wide.index ? 24 : 20;
}

class AppTypographyTheme extends StatelessWidget {
  const AppTypographyTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final type = appTextTheme(context.typeStep, context.primaryTextColor);
    final controlHeight = context.controlHeight;
    final button = ButtonStyle(
      textStyle: WidgetStatePropertyAll(AppType.button.style(context)),
      minimumSize: WidgetStatePropertyAll(Size(0, controlHeight)),
    );
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1.3,
      child: Theme(
        data: base.copyWith(
          textTheme: type,
          primaryTextTheme: type,
          elevatedButtonTheme: ElevatedButtonThemeData(style: button),
          filledButtonTheme: FilledButtonThemeData(style: button),
          outlinedButtonTheme: OutlinedButtonThemeData(style: button),
          textButtonTheme: TextButtonThemeData(style: button),
          tabBarTheme: base.tabBarTheme.copyWith(
            labelStyle: AppType.button.style(context),
            unselectedLabelStyle: AppType.button.style(context),
          ),
          inputDecorationTheme: base.inputDecorationTheme.copyWith(
            labelStyle: AppType.bodySm.style(
              context,
              color: context.primaryTextColor,
              weight: FontWeight.w500,
            ),
            hintStyle: AppType.caption.style(
              context,
              color: context.secondaryTextColor,
            ),
            helperStyle: AppType.caption.style(
              context,
              color: context.secondaryTextColor,
            ),
            errorStyle: AppType.caption.style(
              context,
              color: base.colorScheme.error,
              weight: FontWeight.w600,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

enum StatusTone {
  success(Color(0xFF065F46), Color(0xFFD1FAE5)),
  pending(Color(0xFF92400E), Color(0xFFFEF3C7)),
  error(Color(0xFF991B1B), Color(0xFFFEE2E2)),
  neutral(Color(0xFF334155), Color(0xFFE2E8F0));

  const StatusTone(this.foreground, this.background);

  final Color foreground;
  final Color background;
}
