import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/breath_pattern.dart';
import 'package:women_community_support/data/journal.dart';
import 'package:women_community_support/data/encrypted_box.dart';
import 'package:women_community_support/data/mood.dart';
import 'package:women_community_support/presentation/screens/care/breathe_screen.dart';
import 'package:women_community_support/presentation/screens/care/care_screen.dart';
import 'package:women_community_support/presentation/screens/care/ground_screen.dart';
import 'package:women_community_support/presentation/screens/care/journal_screen.dart';
import 'package:women_community_support/presentation/screens/care/mood_screen.dart';

void _phone(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(420, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
  home: home,
);

/// Lets entrances finish (floating cats loop, so no pumpAndSettle).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ───────────────────────── Care screen ─────────────────────────

  testWidgets('Care: danger card, tools, help lines and guides', (
    tester,
  ) async {
    _phone(tester, height: 3200);
    await tester.pumpWidget(_app(const CareScreen()));
    await _settle(tester);

    expect(find.text('In danger right now?'), findsOneWidget);
    expect(find.text('Call 999'), findsOneWidget);
    for (final tool in [
      'Breathe',
      'Ground yourself',
      'How are you feeling',
      'My journal',
      'Safety plan',
    ]) {
      expect(find.text(tool), findsOneWidget, reason: tool);
    }
    expect(find.text('Talk to someone now'), findsOneWidget);
    expect(find.text('Women and family support'), findsOneWidget);
    expect(find.text('Guides library'), findsOneWidget);
  });

  group('on the web (iPhone browser)', () {
    setUp(() => EncryptedBox.debugPretendWeb = true);
    tearDown(() => EncryptedBox.debugPretendWeb = null);

    testWidgets('mood, journal and safety plan: "Available in the phone app"', (
      tester,
    ) async {
      _phone(tester, height: 3200);
      await tester.pumpWidget(_app(const CareScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      // The private check-in row is not shown at all.
      expect(find.text('How are you today?'), findsNothing);
      // The three private tools stay listed, each with the note.
      expect(find.text(EncryptedBox.webNote), findsNWidgets(3));
      // The calm tools that keep nothing still work.
      expect(find.text('Breathe'), findsOneWidget);
      await tester.tap(find.text('My journal'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(JournalScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening the journal or safety plan another way: a note', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () => openJournal(context),
                    child: const Text('open'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(JournalScreen), findsNothing);
      expect(find.text(EncryptedBox.webNote), findsOneWidget);
    });
  });

  // ───────────────────────── Breathe ─────────────────────────

  group('BreathPattern', () {
    const pattern = BreathPattern();

    test('in 4 s, hold 4 s, out 6 s', () {
      expect(pattern.cycle, const Duration(seconds: 14));
      expect(pattern.at(Duration.zero).phase, BreathPhase.inhale);
      expect(pattern.at(const Duration(seconds: 3)).phase, BreathPhase.inhale);
      expect(pattern.at(const Duration(seconds: 4)).phase, BreathPhase.hold);
      expect(pattern.at(const Duration(seconds: 8)).phase, BreathPhase.exhale);
      expect(pattern.at(const Duration(seconds: 14)).phase, BreathPhase.inhale);
      expect(pattern.at(const Duration(seconds: 14)).cycle, 1);
    });

    test('without hold: in 4 s, out 6 s', () {
      const noHold = BreathPattern(hold: false);
      expect(noHold.cycle, const Duration(seconds: 10));
      expect(noHold.at(const Duration(seconds: 5)).phase, BreathPhase.exhale);
    });

    test('the circle grows when breathing in and shrinks breathing out', () {
      expect(pattern.at(Duration.zero).scale, closeTo(0, 0.01));
      expect(pattern.at(const Duration(seconds: 2)).scale, closeTo(0.5, 0.01));
      expect(pattern.at(const Duration(seconds: 6)).scale, 1);
      expect(pattern.at(const Duration(seconds: 11)).scale, closeTo(0.5, 0.01));
    });

    test('seconds left count down within a phase', () {
      expect(pattern.at(Duration.zero).secondsLeft, 4);
      expect(pattern.at(const Duration(milliseconds: 3500)).secondsLeft, 1);
      expect(pattern.at(const Duration(seconds: 8)).secondsLeft, 6);
    });

    test('a session is whole breaths only', () {
      expect(pattern.breathsIn(const Duration(minutes: 1)), 4); // 56 s
      expect(pattern.breathsIn(const Duration(minutes: 3)), 12);
    });
  });

  group('Breathe screen', () {
    testWidgets('breathes with the cat, then ends kindly', (tester) async {
      _phone(tester, height: 900);
      await tester.pumpWidget(_app(const BreatheScreen()));
      await _settle(tester);
      expect(find.text('1 minute'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Breathe in'), findsOneWidget);
      expect(find.byKey(const ValueKey('breath-circle')), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Hold'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Breathe out'), findsOneWidget);

      // One minute = 4 whole breaths (56 s).
      await tester.pump(const Duration(seconds: 50));
      await _settle(tester);
      expect(find.text(BreatheScreen.doneMessage), findsOneWidget);
    });

    testWidgets('with reduce motion: a counter, no moving circle', (
      tester,
    ) async {
      _phone(tester, height: 900);
      await tester.pumpWidget(_app(const BreatheScreen(), reduceMotion: true));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('breath-circle')), findsNothing);
      final counter = tester.widget<Text>(
        find.byKey(const ValueKey('breath-counter')),
      );
      expect(counter.data, '4');
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('breath-counter'))).data,
        '2',
      );
      await tester.tap(find.text('Stop'));
      await tester.pump();
    });
  });

  // ───────────────────────── Ground ─────────────────────────

  testWidgets('Ground yourself: 5-4-3-2-1, one screen at a time', (
    tester,
  ) async {
    _phone(tester, height: 900);
    await tester.pumpWidget(_app(const GroundScreen(), reduceMotion: true));
    await tester.pump();

    for (final (number, title, _) in GroundScreen.steps) {
      expect(find.text('$number'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(number == 1 ? 'Finish' : 'Next'));
      await tester.pump();
    }
    await _settle(tester);
    expect(find.text(GroundScreen.endMessage), findsOneWidget);
  });

  // ───────────────────────── Mood ─────────────────────────

  group('MoodCalendar', () {
    test('month grid starts on Monday', () {
      // 1 November 2026 is a Sunday: six blanks first.
      final grid = MoodCalendar.monthGrid(2026, 11);
      expect(grid.take(6).every((d) => d == null), isTrue);
      expect(grid[6], DateTime(2026, 11, 1));
      expect(grid.whereType<DateTime>(), hasLength(30));
      expect(grid.length % 7, 0);
    });

    test('February in a leap year', () {
      final grid = MoodCalendar.monthGrid(2028, 2);
      expect(grid.whereType<DateTime>(), hasLength(29));
    });

    test('days logged this week (Monday to today)', () {
      final today = DateTime(2026, 11, 18); // Wednesday
      final entries = {
        for (final d in [16, 18, 12]) // Mon, Wed, and last Thu
          MoodEntry.keyFor(DateTime(2026, 11, d)): MoodEntry(
            day: DateTime(2026, 11, d),
            mood: Mood.okay,
          ),
      };
      expect(MoodCalendar.daysLoggedThisWeek(entries, today), 2);
      expect(MoodCalendar.weeklyLine(2), 'You logged 2 days this week.');
      expect(MoodCalendar.weeklyLine(1), 'You logged 1 day this week.');
      expect(MoodCalendar.weeklyLine(0), contains('Whenever you like'));
    });

    test('no red anywhere in the mood colours', () {
      for (final mood in Mood.values) {
        final c = mood.dot;
        final redDominant = c.r > 0.8 && c.g < 0.4 && c.b < 0.4;
        expect(redDominant, isFalse, reason: mood.name);
      }
    });
  });

  group('Mood screen', () {
    final today = DateTime(2026, 11, 18);

    testWidgets('tap a face, add a note, saved on the phone with a dot', (
      tester,
    ) async {
      _phone(tester);
      final secure = MemorySecureStore();
      final store = MoodStore(secure);
      await tester.pumpWidget(_app(MoodScreen(store: store, today: today)));
      await tester.pumpAndSettle();
      expect(
        find.text('No check-ins yet this week. Whenever you like.'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Good'));
      await tester.pump();
      await tester.enterText(find.byType(CupertinoTextField), 'Nice walk');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await store.load();
      expect(saved[MoodEntry.keyFor(today)]!.mood, Mood.good);
      expect(saved[MoodEntry.keyFor(today)]!.note, 'Nice walk');
      expect(find.byKey(const ValueKey('dot-18')), findsOneWidget);
      expect(find.text('You logged 1 day this week.'), findsOneWidget);
      // Encrypted: the note is not readable in storage.
      expect(secure.values.values.join(), isNot(contains('Nice walk')));
    });

    testWidgets('low or rough offers the help lines, gently', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(MoodScreen(store: MoodStore(MemorySecureStore()), today: today)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Okay'));
      await tester.pump();
      expect(find.text(MoodScreen.helpCardTitle), findsNothing);

      await tester.tap(find.bySemanticsLabel('Rough'));
      await tester.pump();
      expect(find.text(MoodScreen.helpCardTitle), findsOneWidget);
      expect(find.text('See help lines'), findsOneWidget);
    });
  });

  // ───────────────────────── Journal ─────────────────────────

  group('Journal', () {
    test('notes are stored encrypted, newest first', () async {
      final secure = MemorySecureStore();
      var now = DateTime(2026, 11, 18, 9);
      final store = JournalStore(secure, clock: () => now);
      await store.add('First thought about exams');
      now = now.add(const Duration(hours: 1));
      await store.add('Second, a walk helped', prompt: 'What helped today?');

      final entries = await store.load();
      expect(entries.map((e) => e.title), [
        'Second, a walk helped',
        'First thought about exams',
      ]);
      expect(entries.first.prompt, 'What helped today?');
      final raw = secure.values.values.join();
      expect(raw, isNot(contains('exams')));
      expect(raw, isNot(contains('walk')));
    });

    test('edit and delete', () async {
      final store = JournalStore(MemorySecureStore());
      final entry = await store.add('Draft');
      await store.update(entry.id, 'Final words');
      expect((await store.load()).single.text, 'Final words');
      await store.delete(entry.id);
      expect(await store.load(), isEmpty);
    });

    testWidgets('empty journal invites her to write', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          JournalScreen(
            store: JournalStore(MemorySecureStore()),
            prompts: const ['What is on my mind right now?'],
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Your journal is empty'), findsOneWidget);
    });

    testWidgets('write a note from a prompt; it appears in the list', (
      tester,
    ) async {
      _phone(tester, height: 900);
      final store = JournalStore(MemorySecureStore());
      await tester.pumpWidget(
        _app(
          JournalScreen(
            store: store,
            prompts: const ['Something I am grateful for is...'],
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel('New note'));
      await _settle(tester);
      await tester.tap(find.text('Something I am grateful for is...'));
      await _settle(tester);
      expect(find.text('Something I am grateful for is...'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'My sister');
      await tester.tap(find.text('Done'));
      await _settle(tester);

      expect(find.text('My sister'), findsOneWidget);
      final saved = await store.load();
      expect(saved.single.prompt, 'Something I am grateful for is...');
    });

    testWidgets('delete asks first, then removes the note', (tester) async {
      _phone(tester, height: 900);
      final store = JournalStore(MemorySecureStore());
      final entry = await store.add('Remove me');
      await tester.pumpWidget(_app(JournalEditor(store: store, entry: entry)));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Delete note'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this note?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await store.load(), isEmpty);
    });
  });
}
