import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Gentle mode" and "Reduce motion" from the Me tab. Stored on the phone
/// only (SharedPreferences), never in Firestore.
class AppSettings extends ChangeNotifier {
  AppSettings({bool gentleMode = false, bool reduceMotion = false})
    : _gentleMode = gentleMode,
      _reduceMotion = reduceMotion;

  static const String gentleKey = 'looma.settings.gentleMode';
  static const String reduceMotionKey = 'looma.settings.reduceMotion';

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        gentleMode: prefs.getBool(gentleKey) ?? false,
        reduceMotion: prefs.getBool(reduceMotionKey) ?? false,
      );
    } catch (_) {
      return AppSettings();
    }
  }

  bool _gentleMode;
  bool _reduceMotion;

  /// Hides numbers (replies, "me too", how many new discussions), so
  /// nothing feels like a popularity contest.
  bool get gentleMode => _gentleMode;

  /// Turns animations off in the app even if the phone setting is off.
  bool get reduceMotion => _reduceMotion;

  Future<void> setGentleMode(bool value) async {
    if (_gentleMode == value) return;
    _gentleMode = value;
    notifyListeners();
    await _save(gentleKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    await _save(reduceMotionKey, value);
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Still applies for this session.
    }
  }

  /// True when Gentle mode is on. False where no settings are provided
  /// (e.g. in widget tests).
  static bool gentleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
          ?.notifier
          ?.gentleMode ??
      false;
}

/// Makes [AppSettings] available below it and rebuilds readers on change.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);
}
