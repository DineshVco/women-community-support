import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// System / light / dark. Remembered on the phone.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider([this._themeMode = ThemeMode.system]);

  static const String key = 'looma.settings.themeMode';

  static Future<ThemeProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      final mode = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
      return ThemeProvider(mode);
    } catch (_) {
      return ThemeProvider();
    }
  }

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(key, mode.name))
        .catchError((Object _) => false);
  }
}
