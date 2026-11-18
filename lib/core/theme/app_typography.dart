import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale: 12 / 14 / 16 / 18 / 20 / 24 / 28.
///
/// Two families at most:
///  * headings: a serif (Newsreader) — set [headingFont] once the font files
///    are added to the project (see docs/SETUP_STEPS.md).
///  * everything else: Atkinson Hyperlegible — set [bodyFont].
/// While both are `null` the app uses the platform default font.
class AppTypography {
  AppTypography._();

  static const String? headingFont = null; // 'Newsreader'
  static const String? bodyFont = null; // 'AtkinsonHyperlegible'

  static TextStyle _heading(double size, Color color,
      {FontWeight weight = FontWeight.w600, double height = 1.25}) {
    return TextStyle(
      fontFamily: headingFont,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  static TextStyle _body(double size, Color color,
      {FontWeight weight = FontWeight.w400,
      double height = 1.5,
      double letterSpacing = 0}) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme textTheme(AppPalette p) {
    return TextTheme(
      headlineLarge: _heading(28, p.text, height: 1.2),
      headlineMedium: _heading(24, p.text, height: 1.2),
      headlineSmall: _heading(20, p.text),
      titleLarge: _body(18, p.text, weight: FontWeight.w700, height: 1.3),
      titleMedium: _heading(18, p.text, height: 1.3),
      titleSmall: _body(14, p.text, weight: FontWeight.w700, height: 1.3),
      bodyLarge: _body(16, p.text, height: 1.55),
      bodyMedium: _body(14, p.text, height: 1.5),
      bodySmall: _body(12, p.textSecondary, height: 1.4),
      labelLarge: _body(14, p.text, weight: FontWeight.w700, height: 1.2),
      labelMedium: _body(12, p.textSecondary,
          weight: FontWeight.w700, height: 1.2, letterSpacing: 0.2),
      labelSmall: _body(11, p.textSecondary,
          weight: FontWeight.w700, height: 1.2, letterSpacing: 0.3),
    );
  }
}
