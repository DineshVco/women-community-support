import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Two families:
///  * headings and the "Looma" wordmark: Newsreader Regular, a bundled serif
///    (assets/fonts, see pubspec.yaml).
///  * everything else: Figtree, a warm humanist sans, bundled in
///    assets/fonts (works offline, never downloaded).
///
/// Sizes follow the Looma spec: screen titles 32–34 (letter spacing -0.5),
/// body 16 with line height 1.45, buttons 16 weight 500. Small grey text is
/// never under 13, so it stays readable.
class AppTypography {
  AppTypography._();

  static const String headingFont = 'Newsreader';

  /// Body text, buttons and labels.
  static const String bodyFont = 'Figtree';

  /// The smallest size for secondary (grey) text.
  static const double minSecondarySize = 13;

  /// The wordmark sizes: onboarding and the app bar.
  static const double wordmarkLarge = 56;
  static const double wordmarkSmall = 26;

  /// Newsreader Regular at [size].
  static TextStyle heading(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double height = 1.2,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: headingFont,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Caveat handwriting. ONLY for the onboarding line "a safer, brighter
  /// tomorrow" and the Home greeting. The font file ships with the app
  /// (assets/google_fonts), and downloading at runtime is switched off, so
  /// it works offline and never contacts Google.
  static TextStyle script(double size, Color color) {
    GoogleFonts.config.allowRuntimeFetching = false;
    return GoogleFonts.caveat(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.1,
      color: color,
    );
  }

  static TextStyle _body(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
    double letterSpacing = 0,
  }) {
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
      // Screen titles ("Welcome back", "When's your birthday?").
      headlineLarge: heading(34, p.text, height: 1.15, letterSpacing: -0.5),
      // Post title on the discussion page.
      headlineMedium: heading(28, p.text, height: 1.2, letterSpacing: -0.3),
      // Section headings, dialog titles.
      headlineSmall: heading(22, p.text, height: 1.25),
      // App bar titles: the platform font, like iOS navigation bars.
      titleLarge: _body(17, p.text, weight: FontWeight.w600, height: 1.3),
      // Post titles in the feed.
      titleMedium: heading(22, p.text, height: 1.25, letterSpacing: -0.2),
      titleSmall: _body(15, p.text, weight: FontWeight.w600, height: 1.3),
      bodyLarge: _body(16, p.text),
      bodyMedium: _body(15, p.text),
      bodySmall: _body(13, p.textSecondary, height: 1.4),
      // Buttons.
      labelLarge: _body(16, p.text, weight: FontWeight.w500, height: 1.2),
      labelMedium: _body(
        13,
        p.textSecondary,
        weight: FontWeight.w500,
        height: 1.2,
      ),
      // Category labels and small caps.
      labelSmall: _body(
        13,
        p.textSecondary,
        weight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.6,
      ),
    );
  }
}
