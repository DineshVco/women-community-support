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

  static const AppPalette light = AppPalette(
    background: Color(0xFFFFFBF8),
    surface: Color(0xFFFFFFFF),
    softFill: Color(0xFFF4EFEB),
    border: Color(0xFFE8E2DE),
    borderStrong: Color(0xFF111111),
    text: Color(0xFF111111),
    textSecondary: Color(0xFF6B6B6B),
    textMuted: Color(0xFF767676),
    primary: Color(0xFF111111),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFC8553D),
    blush: Color(0xFFE9B8B3),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBEAE9),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0E0E0E),
    surface: Color(0xFF161615),
    softFill: Color(0xFF1F1E1C),
    border: Color(0xFF3A3835),
    borderStrong: Color(0xFFF5F2EC),
    text: Color(0xFFF5F2EC),
    textSecondary: Color(0xFF9A9690),
    textMuted: Color(0xFF8C8882),
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
