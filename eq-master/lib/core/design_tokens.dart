import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF4A647A);
  static const Color primaryDark = Color(0xFF344A5D);
  static const Color primaryLight = Color(0xFFD8E2EA);
  static const Color surfaceDark = Color(0xFF1B3A2D);
  static const Color success = Color(0xFF2E7D32);

  /// Brand green used for primary actions and outlines across the app.
  static const Color brand = Colors.green;

  /// Green stroke for outlined buttons (see note: "outlined button stroke
  /// should be green").
  static const Color outline = Colors.green;

  // ── Surface fills (75% opacity) ───────────────────────────────────────────
  // Cards and input fields share the SAME fill, per the design notes:
  // "all app input fields should be the same as cards colors with opacity 75%".
  static const Color _cardFillLight = Color(0xBFFFFFFF); // white  @ ~75%
  static const Color _cardFillDark = Color(0xBF14241B); // dark green @ ~75%

  /// Card / input background for the current brightness.
  static Color cardFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _cardFillDark
          : _cardFillLight;

  /// Input fill === card fill (intentionally identical).
  static Color inputFill(BuildContext context) => cardFill(context);

  /// Primary text color for the current brightness.
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  /// Secondary / hint text color for the current brightness.
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white54
          : Colors.black54;

  /// Translucent scrim used behind editing overlays / cancel buttons.
  static Color overlayScrim(BuildContext context) =>
      Colors.black.withValues(alpha: 0.04);
}

class AppSpacing {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
  static const double xxl = 48;
}

/// Single source of truth for corner radii. Resolves the
/// "inconsistent roundness through app buttons / fields" notes.
class AppRadius {
  static const double sm = 8;
  static const double md = 12;

  /// Default radius for cards and input fields across the app.
  static const double lg = 16;
  static const double xl = 24;

  /// Fully rounded — used for primary / outlined action buttons.
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get input => BorderRadius.circular(lg);
  static BorderRadius get button => BorderRadius.circular(pill);
}
