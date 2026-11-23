import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/data/today_for_you.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';
import 'package:women_community_support/presentation/widgets/looma_card.dart';
import 'package:women_community_support/presentation/widgets/today_for_you_card.dart';

final String _json = File('content/today_for_you.json').readAsStringSync();
final TodayForYou _real = TodayForYou.parse(_json);

ContentLibrary _library() => ContentLibrary.parse(
  guidesJson: File('content/guides.json').readAsStringSync(),
  directoryJson: File('content/directory.json').readAsStringSync(),
  todayForYouJson: _json,
);

DateTime _at(int h, [int m = 0, int day = 23]) => DateTime(2026, 11, day, h, m);

Widget _app(
  Widget child, {
  ThemeData? theme,
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [child]),
    ),
  ),
);

void main() {
  group('time slots (local time)', () {
    test('each slot, and every boundary', () {
      TodaySlot at(int h, [int m = 0]) => TodaySlot.forTime(_at(h, m));
      expect(at(4, 59), TodaySlot.night);
      expect(at(5), TodaySlot.morning);
      expect(at(11, 59), TodaySlot.morning);
      expect(at(12), TodaySlot.afternoon);
      expect(at(16, 59), TodaySlot.afternoon);
      expect(at(17), TodaySlot.evening);
      expect(at(21, 59), TodaySlot.evening);
      expect(at(22), TodaySlot.night);
      expect(at(0), TodaySlot.night);
    });
  });

  group('one suggestion per day', () {
    test('the same all through a slot', () {
      for (final (from, to) in [
        (_at(5), _at(11, 59)),
        (_at(12), _at(16, 59)),
        (_at(17), _at(21, 59)),
      ]) {
        expect(
          _real.pick(from, includeDrafts: true)!.id,
          _real.pick(to, includeDrafts: true)!.id,
        );
      }
    });

    test('late night does not change at midnight', () {
      final before = _real.pick(_at(23, 30), includeDrafts: true)!;
      final after = _real.pick(_at(2, 0, 24), includeDrafts: true)!;
      expect(after.id, before.id);
    });

    test('it moves on from day to day', () {
      final ids = {
        for (var d = 1; d <= 8; d++)
          _real.pick(_at(9, 0, d), includeDrafts: true)!.id,
      };
      expect(ids.length, greaterThan(1));
    });

    test('release builds show only checked suggestions', () {
      // Everything is still a draft, so nothing shows in release.
      expect(_real.pick(_at(9), includeDrafts: false), isNull);
      final checked = TodayForYou({
        TodaySlot.morning: const [
          TodaySuggestion(id: 'a', title: 'A', text: 'a', target: 'breathe'),
          TodaySuggestion(
            id: 'b',
            title: 'B',
            text: 'b',
            target: 'ground',
            verified: true,
          ),
        ],
      });
      expect(checked.pick(_at(9), includeDrafts: false)!.id, 'b');
    });
  });

  group('content/today_for_you.json', () {
    test('3 to 5 short suggestions per slot, all waiting for Najwa', () {
      final raw = jsonDecode(_json) as Map<String, dynamic>;
      final slots = raw['slots'] as Map<String, dynamic>;
      for (final slot in TodaySlot.values) {
        final list = slots[slot.name] as List;
        expect(list.length, inInclusiveRange(3, 5), reason: slot.name);
        // Every item parsed (no typo in a target).
        expect(_real.slots[slot], hasLength(list.length), reason: slot.name);
        for (final item in list.cast<Map<String, dynamic>>()) {
          expect(item['verified'], isFalse, reason: item['id'] as String);
          expect((item['text'] as String).length, lessThan(120));
        }
      }
    });

    test('targets are real: breathe, ground, journal or an existing guide', () {
      final guideIds = _library().guides.map((g) => g.id).toSet();
      final ids = <String>{};
      for (final s in _real.slots.values.expand((l) => l)) {
        expect(ids.add(s.id), isTrue, reason: 'duplicate id ${s.id}');
        expect(s.kind, isNotNull, reason: s.id);
        if (s.kind == TodayTargetKind.guide) {
          expect(guideIds, contains(s.guideId), reason: s.id);
        }
      }
    });

    test('each slot has the right kind of help', () {
      Set<TodayTargetKind?> kinds(TodaySlot slot) =>
          _real.slots[slot]!.map((s) => s.kind).toSet();
      expect(kinds(TodaySlot.night), contains(TodayTargetKind.breathe));
      expect(kinds(TodaySlot.evening), contains(TodayTargetKind.journal));
      expect(kinds(TodaySlot.afternoon), contains(TodayTargetKind.ground));
    });

    test('the bundled library loads it', () {
      expect(
        _library().todayForYou.pick(_at(9), includeDrafts: true),
        isNotNull,
      );
    });
  });

  group('the card', () {
    for (final (name, theme, scale, time) in [
      ('320 px, 2x text, morning', AppTheme.light, 2.0, _at(9)),
      ('320 px, dark mode, late night', AppTheme.dark, 1.0, _at(23)),
      ('320 px, 2x text, evening', AppTheme.light, 2.0, _at(19)),
    ]) {
      testWidgets('$name: no overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            TodayForYouCard(
              onOpen: (_) {},
              now: time,
              library: _library(),
              includeDrafts: true,
            ),
            theme: theme,
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining(TodayForYouCard.heading), findsOneWidget);
      });
    }

    testWidgets('a cat-in-the-grass picture on the right; text stays left', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final suggestion = _real.pick(_at(9), includeDrafts: true)!;
      await tester.pumpWidget(
        _app(
          TodayForYouCard(
            onOpen: (_) {},
            now: _at(9),
            library: _library(),
            includeDrafts: true,
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      // Wait (up to 2 s) for the app to find the picture in its bundle.
      final picture = find.descendant(
        of: find.byKey(const ValueKey('today-picture')),
        matching: find.byType(Image),
      );
      for (var i = 0; i < 100 && picture.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('today-picture')), findsOneWidget);
      // The napping cat picture.
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('today-picture')),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as AssetImage).assetName, CardPictures.catNap);
      expect(find.byKey(const ValueKey('card-picture-fallback')), findsNothing);
      final card = tester.getRect(find.byType(LoomaCard));
      final pictureStarts =
          card.right - TodayForYouCard.textRightInset(card.width);
      for (final text in [suggestion.title, suggestion.text]) {
        expect(
          tester.getRect(find.text(text)).right,
          lessThanOrEqualTo(pictureStarts + 0.5),
        );
      }
    });

    testWidgets('late night is quieter: a plain soft card', (tester) async {
      Future<Color?> colourAt(DateTime time) async {
        await tester.pumpWidget(
          _app(
            TodayForYouCard(
              onOpen: (_) {},
              now: time,
              library: _library(),
              includeDrafts: true,
            ),
          ),
        );
        return tester.widget<LoomaCard>(find.byType(LoomaCard)).color;
      }

      expect(await colourAt(_at(9)), isNull); // normal surface
      expect(await colourAt(_at(23)), isNotNull); // soft fill
    });

    testWidgets('tapping opens the suggestion', (tester) async {
      TodaySuggestion? opened;
      final expected = _real.pick(_at(19), includeDrafts: true)!;
      await tester.pumpWidget(
        _app(
          TodayForYouCard(
            onOpen: (s) => opened = s,
            now: _at(19),
            library: _library(),
            includeDrafts: true,
          ),
        ),
      );
      await tester.tap(find.text(expected.title));
      await tester.pumpAndSettle();
      expect(opened?.id, expected.id);
    });

    testWidgets('nothing to show: no empty card', (tester) async {
      await tester.pumpWidget(
        _app(
          TodayForYouCard(
            onOpen: (_) {},
            now: _at(9),
            library: _library(),
            includeDrafts: false,
          ),
        ),
      );
      expect(find.byType(LoomaCard), findsNothing);
    });

    testWidgets('Reduce motion: nothing keeps animating', (tester) async {
      await tester.pumpWidget(
        _app(
          TodayForYouCard(
            onOpen: (_) {},
            now: _at(14),
            library: _library(),
            includeDrafts: true,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
