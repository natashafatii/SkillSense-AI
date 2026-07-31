import 'package:flutter/material.dart';

class Responsive {
  // Breakpoints
  static const double mobileMax = 599;
  static const double tabletMax = 1023;
  static const double desktopMax = 1439;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mobileMax;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width > mobileMax &&
      MediaQuery.of(context).size.width <= tabletMax;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > tabletMax &&
      MediaQuery.of(context).size.width <= desktopMax;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width > desktopMax;

  // Responsive scaling utilities
  static double getFontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? wide,
  }) {
    double width = MediaQuery.of(context).size.width;
    if (width <= mobileMax) {
      return mobile;
    } else if (width <= tabletMax) {
      return tablet ?? mobile * 1.1;
    } else if (width <= desktopMax) {
      return desktop ?? tablet ?? mobile * 1.2;
    } else {
      return wide ?? desktop ?? tablet ?? mobile * 1.2;
    }
  }

  static double getSpacing(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? wide,
  }) {
    double width = MediaQuery.of(context).size.width;
    if (width <= mobileMax) {
      return mobile;
    } else if (width <= tabletMax) {
      return tablet ?? mobile * 1.2;
    } else if (width <= desktopMax) {
      return desktop ?? tablet ?? mobile * 1.5;
    } else {
      return wide ?? desktop ?? tablet ?? mobile * 1.5;
    }
  }

  // Web Split-Layout Panel Constraints
  static const double webLayoutMaxWidth = 1920.0;
  static const double leftPanelContentMaxWidth = 780.0;
  static const double rightPanelContentMaxWidth = 680.0;
}
