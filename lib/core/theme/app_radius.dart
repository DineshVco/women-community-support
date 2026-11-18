/// Corner radii. Different components use different radii on purpose,
/// instead of rounding everything the same amount.
class AppRadius {
  AppRadius._();

  /// Small tags and badges.
  static const double tag = 4.0;

  /// Buttons, inputs, chips, menus.
  static const double control = 8.0;

  /// Grouped surfaces and dialogs.
  static const double card = 12.0;

  /// Top corners of bottom sheets.
  static const double sheet = 16.0;
}
