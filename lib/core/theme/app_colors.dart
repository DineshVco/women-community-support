import 'package:flutter/material.dart';

/// Looma colour palette.
///
/// Calm and plain: black, white and warm greys, plus a soft blush touch.
///  * blush (#E9B8B3) is decorative only: the glow behind the character,
///    selected option cards, the active page dot, "Me too" when pressed and
///    the star next to the wordmark. Never for text (it is too pale to read).
///  * accent (terracotta) stays for category labels, which are text.
/// No gradients, no shadows. Dark mode inverts the scheme.
///
/// Use it from any widget with `context.palette`.
@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.softFill,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.blush,
    required this.danger,
    required this.dangerSoft,
  });

  final Color background;

  /// Cards, fields, sheets.
  final Color surface;

  /// Quiet grey fill: icon circles, info boxes, selected backgrounds.
  final Color softFill;

  /// 1 px lines between rows, card and field outlines.
  final Color border;

  /// Selected options and focused fields (black in light mode).
  final Color borderStrong;

  final Color text;
  final Color textSecondary;

  /// Hints and placeholders.
  final Color textMuted;

  /// Buttons and selected states: black in light mode.
  final Color primary;
  final Color onPrimary;

  /// Category labels only (readable text colour).
  final Color accent;

  /// Soft blush. Decorative only, see the class comment.
  final Color blush;

  /// Text/icons on a blush background.
  Color get onBlush => const Color(0xFF111111);

  /// Behind the line drawings in dark mode: soft off-white (the drawings
  /// have dark lines), never a glaring pure white block.
  static const Color illustrationCard = Color(0xFFE9E5DF);

  /// A faint blush wash, e.g. for a selected option card.
  Color get blushTint =>
      Color.alphaBlend(blush.withValues(alpha: 0.22), surface);

  /// Get help screen, Report, destructive actions.
  final Color danger;
  final Color dangerSoft;

  // ── Older names, kept so existing screens keep working. ──

  /// Same as [softFill].
  Color get primarySoft => softFill;

  /// "Post removed" outcome. Plain text colour: no extra colours in Looma.
  Color get success => text;

  /// "Waiting for review". Uses the accent.
  Color get warning => accent;

  /// Every category label uses the accent.
  Color categoryColor(String categoryId) => accent;

  bool get _isDark => background.computeLuminance() < 0.2;

  /// The soft fill of a category pill: Health sage, Education sand,
  /// Career blush, Safety lavender (deep tints in dark mode). The pill's
  /// text is [text], which passes AA on all of them.
  Color categoryFill(String categoryId) => switch (categoryId) {
    'health_wellness' =>
      _isDark ? const Color(0xFF26302A) : const Color(0xFFE3ECE2),
    'education' => _isDark ? const Color(0xFF332C20) : const Color(0xFFF3E8D3),
    'career_development' =>
      _isDark ? const Color(0xFF3A2624) : const Color(0xFFF8E1DD),
    'personal_safety' =>
      _isDark ? const Color(0xFF2C2838) : const Color(0xFFE9E4F2),
    _ => softFill,
  };

  /// Soft circles behind line-art avatars and tool icons.
  List<Color> get softTints => [
    for (final id in const [
      'health_wellness',
      'education',
      'career_development',
      'personal_safety',
    ])
      categoryFill(id),
  ];

  static const AppPalette light = AppPalette(
    background: Color(0xFFFBF7F3), // warm off-white
    surface: Color(0xFFFFFFFF),
    softFill: Color(0xFFF4EFEB),
    border: Color(0xFFE8E2DE),
    borderStrong: Color(0xFF111111),
    text: Color(0xFF111111),
    // Warm greys, at least 5:1 on every light background (AA).
    textSecondary: Color(0xFF5E5953),
    textMuted: Color(0xFF66615B),
    primary: Color(0xFF111111),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFC8553D),
    blush: Color(0xFFE9B8B3),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBEAE9),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0E0E0E),
    // Raised surfaces are a little lighter than the background (as on iOS).
    surface: Color(0xFF1C1B1A),
    softFill: Color(0xFF2A2927),
    border: Color(0xFF3A3835),
    borderStrong: Color(0xFFF5F2EC),
    text: Color(0xFFF5F2EC),
    // At least 5:1 on every dark background (AA).
    textSecondary: Color(0xFFA8A39C),
    textMuted: Color(0xFF9E9992),
    primary: Color(0xFFF5F2EC),
    onPrimary: Color(0xFF111111),
    // Lighter shade of the accent so small labels stay readable on black.
    accent: Color(0xFFE07A62),
    blush: Color(0xFFE9B8B3),
    danger: Color(0xFFF2B8B5),
    dangerSoft: Color(0xFF3A1D1B),
  );
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
}
