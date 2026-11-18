import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether to play the little heart burst after a post.
///
/// It plays once per account: after her very first post. The "already
/// celebrated" flag is stored on the phone (SharedPreferences), never in
/// Firestore.
class FirstPostCelebration {
  FirstPostCelebration._();

  static String keyFor(String uid) => 'looma.firstPostCelebrated.$uid';

  /// True only the first time it is asked for [uid], and only when this
  /// really is her first post ([postCount] == 1). That stops people who
  /// posted before (on this phone or another one) getting it later.
  ///
  /// The flag is saved before the burst plays, so it can never repeat.
  static Future<bool> claim(
    String uid, {
    required Future<int> Function() postCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(uid);
    if (prefs.getBool(key) ?? false) return false;

    await prefs.setBool(key, true);

    try {
      return await postCount() == 1;
    } catch (_) {
      // Offline or the count failed: celebrate rather than stay silent.
      return true;
    }
  }
}
