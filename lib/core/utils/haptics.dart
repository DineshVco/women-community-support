import 'package:flutter/services.dart';

/// Haptic feedback with one meaning per kind of action, used sparingly so it
/// stays meaningful.
///
/// Deliberately NOT used on "Quick exit": a buzz could draw attention at
/// exactly the moment someone is trying to hide the app.
class AppHaptics {
  AppHaptics._();

  /// Picking between options: tabs, category chips, theme, report reason.
  static void selection() => HapticFeedback.selectionClick();

  /// A small action happened: post published, "Me too", mood saved, a
  /// vote, a reply sent.
  static void light() => HapticFeedback.lightImpact();

  /// Something important finished: refresh started, a moderation
  /// decision saved, a report sent.
  static void medium() => HapticFeedback.mediumImpact();

  /// Before a destructive action: delete, remove.
  static void warning() => HapticFeedback.heavyImpact();
}
