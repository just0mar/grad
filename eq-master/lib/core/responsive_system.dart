import 'package:flutter/material.dart';

class ResponsiveSystem {
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1024;
  static const double desktopMaxWidth = 1536;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) => width(context) < mobileMaxWidth;

  static bool isTablet(BuildContext context) =>
      width(context) >= mobileMaxWidth && width(context) < tabletMaxWidth;

  static bool isDesktop(BuildContext context) =>
      width(context) >= tabletMaxWidth;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  static double horizontalPadding(BuildContext context) {
    final double screenWidth = width(context);
    if (screenWidth < 360) return 16;
    if (screenWidth < 600) return 24;
    if (screenWidth < 1024) return 32;
    return 48;
  }

  static double verticalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final double horizontal = horizontalPadding(context);
    final double vertical = verticalPadding(context);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static double buttonHeight(BuildContext context) {
    if (isMobile(context)) return 48;
    if (isTablet(context)) return 56;
    return 56;
  }

  static double cardHeight(BuildContext context) {
    if (isMobile(context)) return 120;
    if (isTablet(context)) return 140;
    return 160;
  }

  static double titleFontSize(BuildContext context) {
    if (isMobile(context)) return 22;
    if (isTablet(context)) return 24;
    return 26;
  }

  static double subtitleFontSize(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 18;
    return 20;
  }

  static double bodyFontSize(BuildContext context) {
    if (isMobile(context)) return 14;
    if (isTablet(context)) return 15;
    return 16;
  }

  static double verticalGap(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }

  static double horizontalGap(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }

  static int gridColumns(BuildContext context) {
    final double screenWidth = width(context);
    if (screenWidth < 420) return 1;
    if (screenWidth < 900) return 2;
    if (screenWidth < 1200) return 3;
    return 4;
  }

  static double maxContentWidth(BuildContext context) {
    return width(context) < desktopMaxWidth ? width(context) : desktopMaxWidth;
  }
}
