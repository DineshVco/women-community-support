import 'package:flutter/material.dart';

/// HerCircle colour palette.
///
/// Warm paper neutrals + one deep-green accent. Every text/background pair
/// below was checked against WCAG AA (4.5:1 for text).
///
/// Use it from any widget with `context.palette`.
@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.warning,
    required this.health,
    required this.education,
    required this.career,
    required this.safety,
  });

  final Color background;
  final Color surface;

  /// Hairline dividers and card outlines (decorative).
  final Color border;

  /// Borders of interactive controls such as inputs (needs 3:1 contrast).
  final Color borderStrong;

  final Color text;
  final Color textSecondary;
  final Color textMuted;

  final Color primary;
  final Color onPrimary;
  final Color primarySoft;

  /// Warm clay, used sparingly for highlights.
  final Color accent;

  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color warning;

  // Category text colours.
  final Color health;
  final Color education;
  final Color career;
  final Color safety;

  Color categoryColor(String categoryId) {
    switch (categoryId) {
      case 'health_wellness':
        return health;
      case 'education':
        return education;
      case 'career_development':
        return career;
      case 'personal_safety':
        return safety;
      default:
        return textSecondary;
    }
  }

  static const AppPalette light = AppPalette(
    background: Color(0xFFF7F3EC),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE4DDD0),
    borderStrong: Color(0xFF8C8374),
    text: Color(0xFF221E1A),
    textSecondary: Color(0xFF5C544B),
    textMuted: Color(0xFF766D62),
    primary: Color(0xFF1F5F54),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE1EDE9),
    accent: Color(0xFFA8482A),
    danger: Color(0xFFA63A2B),
    dangerSoft: Color(0xFFF6E3DF),
    success: Color(0xFF2F6B3A),
    warning: Color(0xFF8A5A00),
    health: Color(0xFF9A4A30),
    education: Color(0xFF34577E),
    career: Color(0xFF5A6620),
    safety: Color(0xFF7A3E64),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF141311),
    surface: Color(0xFF1D1B18),
    border: Color(0xFF34302A),
    borderStrong: Color(0xFF756E62),
    text: Color(0xFFEFEAE0),
    textSecondary: Color(0xFFB8B0A3),
    textMuted: Color(0xFF9A9286),
    primary: Color(0xFF7CC4B3),
    onPrimary: Color(0xFF0F2A25),
    primarySoft: Color(0xFF1F2F2B),
    accent: Color(0xFFE39A82),
    danger: Color(0xFFF0907F),
    dangerSoft: Color(0xFF3A1F1B),
    success: Color(0xFF8CCB9B),
    warning: Color(0xFFE0B25A),
    health: Color(0xFFE39A82),
    education: Color(0xFF8FB2DA),
    career: Color(0xFFB5C46A),
    safety: Color(0xFFD69BBF),
  );
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}
