import 'package:shared_preferences/shared_preferences.dart';

/// Whether this phone has finished the introduction, kept across launches
/// (shared_preferences, a plain yes/no; nothing personal).
class OnboardingProgress {
  OnboardingProgress._();

  static const String key = 'looma.onboarding.seen';

  /// False if it cannot be read, so the introduction shows again rather
  /// than never.
  static Future<bool> seen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }
}
