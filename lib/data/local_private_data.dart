import 'content_library.dart';
import 'journal.dart';
import 'mood.dart';
import 'safety_plan.dart';

/// How "Delete my account and data" ends.
enum DeletionOutcome {
  /// Everything is gone, the login too.
  done,

  /// The private data on this phone could not be deleted and she chose not
  /// to try again now: her login is kept, so she can finish later.
  loginKept,
}

/// The last steps of account deletion, in a safe order: the private data on
/// this phone must be gone BEFORE the login is deleted. If it cannot be
/// deleted, she is asked whether to try again ([askRetry]); the login is
/// never deleted until the phone data is.
class AccountDeletion {
  AccountDeletion._();

  static Future<DeletionOutcome> finish({
    required Future<bool> Function() deleteLocal,
    required Future<void> Function() deleteLogin,
    required Future<bool> Function() askRetry,
  }) async {
    while (!await deleteLocal()) {
      if (!await askRetry()) return DeletionOutcome.loginKept;
    }
    await deleteLogin();
    return DeletionOutcome.done;
  }
}

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
