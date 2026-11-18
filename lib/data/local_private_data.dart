import 'content_library.dart';
import 'journal.dart';
import 'mood.dart';
import 'safety_plan.dart';

/// Everything private that lives only on this phone: the mood log, the
/// journal and the safety plan (each encrypted, with its own key), and the
/// bookmarked guides.
///
/// "Delete my account and data" wipes all of it, so nothing personal is
/// left behind on the phone either.
class LocalPrivateData {
  const LocalPrivateData({
    required this.moodLog,
    required this.journal,
    required this.safetyPlan,
    this.guideBookmarks,
  });

  final MoodStore moodLog;
  final JournalStore journal;
  final SafetyPlanStore safetyPlan;
  final GuideBookmarks? guideBookmarks;

  /// Deletes the data and the keys. Keeps going if one part fails, and
  /// reports whether everything was deleted.
  Future<bool> deleteAll() async {
    var ok = true;
    for (final clear in [
      moodLog.clear,
      journal.clear,
      safetyPlan.clear,
      if (guideBookmarks != null) guideBookmarks!.clear,
    ]) {
      try {
        await clear();
      } catch (_) {
        ok = false;
      }
    }
    return ok;
  }
}
