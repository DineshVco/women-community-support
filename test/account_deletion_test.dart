import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/data/journal.dart';
import 'package:women_community_support/data/local_private_data.dart';
import 'package:women_community_support/data/mood.dart';
import 'package:women_community_support/data/safety_plan.dart';
import 'package:women_community_support/presentation/screens/me/privacy_centre_screen.dart';

/// A phone whose storage refuses to delete one item.
class StubbornStore extends MemorySecureStore {
  StubbornStore(this.stuckKey);

  final String stuckKey;

  @override
  Future<void> delete(String key) async {
    if (key == stuckKey) throw Exception('storage error');
    return super.delete(key);
  }
}

Future<LocalPrivateData> _filled(MemorySecureStore secure) async {
  final mood = MoodStore(secure);
  final journal = JournalStore(secure);
  final plan = SafetyPlanStore(secure);
  await mood.save(MoodEntry(day: DateTime(2026, 11, 18), mood: Mood.low));
  await journal.add('A private note');
  await plan.save(
    const SafetyPlan(
      contacts: [SafeContact(name: 'Aunty Rose', number: '012-345 6789')],
      codeWord: 'pineapple',
    ),
  );
  final bookmarks = GuideBookmarks(secure);
  await bookmarks.toggle('low-mood');
  return LocalPrivateData(
    moodLog: mood,
    journal: journal,
    safetyPlan: plan,
    guideBookmarks: bookmarks,
  );
}

void main() {
  group('Delete my account and data', () {
    test(
      'also deletes the mood log, journal, safety plan and bookmarks',
      () async {
        final secure = MemorySecureStore();
        final local = await _filled(secure);
        expect(secure.values, isNotEmpty);

        expect(await local.deleteAll(), isTrue);

        // Nothing left on the phone: no data and no keys.
        expect(secure.values, isEmpty);
        expect(await local.moodLog.load(), isEmpty);
        expect(await local.journal.load(), isEmpty);
        expect((await local.safetyPlan.load()).isEmpty, isTrue);
        expect(await local.guideBookmarks!.load(), isEmpty);
      },
    );

    test('keeps going if one part cannot be deleted', () async {
      final secure = StubbornStore('looma.mood.data');
      final local = await _filled(secure);

      expect(await local.deleteAll(), isFalse);
      // The journal and safety plan are still deleted.
      expect(await local.journal.load(), isEmpty);
      expect((await local.safetyPlan.load()).isEmpty, isTrue);
    });

    test('the login is deleted only after the phone data is gone', () async {
      final steps = <String>[];
      final outcome = await AccountDeletion.finish(
        deleteLocal: () async {
          steps.add('local');
          return true;
        },
        deleteLogin: () async => steps.add('login'),
        askRetry: () async => fail('no need to ask'),
      );
      expect(outcome, DeletionOutcome.done);
      expect(steps, ['local', 'login']);
    });

    test('phone data fails: asks, retries, then deletes the login', () async {
      var attempts = 0;
      var asked = 0;
      var loginDeleted = false;
      final outcome = await AccountDeletion.finish(
        deleteLocal: () async => ++attempts >= 3, // fails twice
        deleteLogin: () async => loginDeleted = true,
        askRetry: () async {
          asked++;
          expect(loginDeleted, isFalse); // never before the data is gone
          return true;
        },
      );
      expect(outcome, DeletionOutcome.done);
      expect(asked, 2);
      expect(loginDeleted, isTrue);
    });

    test(
      'phone data fails and she says "Not now": the login is kept',
      () async {
        var loginDeleted = false;
        final outcome = await AccountDeletion.finish(
          deleteLocal: () async => false,
          deleteLogin: () async => loginDeleted = true,
          askRetry: () async => false,
        );
        expect(outcome, DeletionOutcome.loginKept);
        expect(loginDeleted, isFalse);
      },
    );

    test(
      'with a phone that refuses, the real data reports the failure',
      () async {
        final secure = StubbornStore('looma.mood.data');
        final local = await _filled(secure);
        var loginDeleted = false;
        final outcome = await AccountDeletion.finish(
          deleteLocal: local.deleteAll,
          deleteLogin: () async => loginDeleted = true,
          askRetry: () async => false,
        );
        expect(outcome, DeletionOutcome.loginKept);
        expect(loginDeleted, isFalse);
      },
    );

    test('the failure message is plain and honest', () {
      expect(
        PrivacyCentreScreen.localDeleteFailedMessage,
        allOf(contains('could not be removed'), contains('login is kept')),
      );
    });

    test('the confirmation says the phone data goes too', () {
      for (final text in [
        PrivacyCentreScreen.deleteConfirmMessage,
        PrivacyCentreScreen.deleteSummary,
      ]) {
        expect(text, contains('mood log'));
        expect(text, contains('journal'));
        expect(text, contains('safety plan'));
        expect(text, contains('this phone'));
      }
      expect(
        PrivacyCentreScreen.deleteConfirmMessage,
        contains('cannot be undone'),
      );
    });
  });
}
