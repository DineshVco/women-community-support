/// Corner radii from the Looma spec.
class AppRadius {
  AppRadius._();

  /// Small tags such as "Original poster".
  static const double tag = 6.0;

  /// Info boxes and small surfaces inside a screen.
  static const double control = 12.0;

  /// Cards, option cards, dialogs.
  static const double card = 20.0;

  /// Text fields.
  static const double field = 18.0;

  /// Category chips are fully round (StadiumBorder); kept for reference.
  static const double chip = 999.0;

  /// Buttons (fully round at 56 px high).
  static const double button = 28.0;

  /// Top corners of bottom sheets.
  static const double sheet = 16.0;
}
