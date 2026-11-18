/// Spacing scale 4, 8, 12, 16, 24, 32 (Looma spec). Use these instead of
/// ad-hoc numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Left/right page gutter.
  static const double screenHorizontal = 24.0;

  /// Content never gets wider than this (tablet / web).
  static const double maxContentWidth = 640.0;

  /// Minimum touch target.
  static const double touchTarget = 48.0;

  /// Black primary button.
  static const double buttonHeight = 56.0;

  /// Outline button.
  static const double outlineButtonHeight = 52.0;
}
