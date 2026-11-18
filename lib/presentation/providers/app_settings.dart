import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which screen Quick exit shows.
enum QuickExitScreen {
  weather('Weather'),
  calculator('Calculator');

  const QuickExitScreen(this.label);
  final String label;
}

/// Settings from the Me tab: Gentle mode, Reduce motion, the Quick exit
/// screen and the weather city. Stored on the phone only
/// (SharedPreferences), never in Firestore.
class AppSettings extends ChangeNotifier {
  AppSettings({
    bool gentleMode = false,
    bool reduceMotion = false,
    QuickExitScreen quickExitScreen = QuickExitScreen.weather,
    String weatherCity = defaultCity,
  }) : _gentleMode = gentleMode,
       _reduceMotion = reduceMotion,
       _quickExitScreen = quickExitScreen,
       _weatherCity = weatherCity;

  static const String defaultCity = 'Kuala Lumpur';
  static const String quickExitKey = 'looma.settings.quickExitScreen';
  static const String cityKey = 'looma.settings.weatherCity';

  static const String gentleKey = 'looma.settings.gentleMode';
  static const String reduceMotionKey = 'looma.settings.reduceMotion';

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        gentleMode: prefs.getBool(gentleKey) ?? false,
        reduceMotion: prefs.getBool(reduceMotionKey) ?? false,
        quickExitScreen: QuickExitScreen.values.firstWhere(
          (s) => s.name == prefs.getString(quickExitKey),
          orElse: () => QuickExitScreen.weather,
        ),
        weatherCity: prefs.getString(cityKey) ?? defaultCity,
      );
    } catch (_) {
      return AppSettings();
    }
  }

  bool _gentleMode;
  bool _reduceMotion;
  QuickExitScreen _quickExitScreen;
  String _weatherCity;

  QuickExitScreen get quickExitScreen => _quickExitScreen;

  /// City shown on the weather disguise.
  String get weatherCity => _weatherCity;

  Future<void> setQuickExitScreen(QuickExitScreen value) async {
    if (_quickExitScreen == value) return;
    _quickExitScreen = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(quickExitKey, value.name);
    } catch (_) {}
  }

  Future<void> setWeatherCity(String city) async {
    final value = city.trim().isEmpty ? defaultCity : city.trim();
    if (_weatherCity == value) return;
    _weatherCity = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cityKey, value);
    } catch (_) {}
  }

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

  /// The settings, or null where none are provided (e.g. widget tests).
  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;

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
