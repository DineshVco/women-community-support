import 'journal.dart';
import 'mood.dart';
import 'safety_plan.dart';

/// Everything private that lives only on this phone: the mood log, the
/// journal and the safety plan (each encrypted, with its own key).
///
/// "Delete my account and data" wipes all of it, so nothing personal is
/// left behind on the phone either.
class LocalPrivateData {
  const LocalPrivateData({
    required this.moodLog,
    required this.journal,
    required this.safetyPlan,
  });

  final MoodStore moodLog;
  final JournalStore journal;
  final SafetyPlanStore safetyPlan;

  /// Deletes the data and the keys. Keeps going if one part fails, and
  /// reports whether everything was deleted.
  Future<bool> deleteAll() async {
    var ok = true;
    for (final clear in [
      moodLog.clear,
      journal.clear,
      safetyPlan.clear,
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
