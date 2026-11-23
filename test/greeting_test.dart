import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/greeting.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';
import 'package:women_community_support/presentation/widgets/hero_card.dart';

import 'support/real_fonts.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);

void main() {
  group('the greeting, by local time', () {
    test('each slot with her name, and every boundary', () {
      String g(int h, [int m = 0]) => greetingFor(_at(h, m), name: 'Bee');
      expect(g(5), 'Good morning, Bee');
      expect(g(11, 59), 'Good morning, Bee');
      expect(g(12), 'Good afternoon, Bee');
      expect(g(16, 59), 'Good afternoon, Bee');
      expect(g(17), 'Good evening, Bee');
      expect(g(21, 59), 'Good evening, Bee');
      expect(g(22), 'Take a breath, Bee.');
      expect(g(0), 'Take a breath, Bee.');
      expect(g(4, 59), 'Take a breath, Bee.');
    });

    test('no name: no comma and no name', () {
      expect(greetingFor(_at(9)), 'Good morning');
      expect(greetingFor(_at(14)), 'Good afternoon');
      expect(greetingFor(_at(19)), 'Good evening');
      expect(greetingFor(_at(23)), 'Take a breath.');
      expect(greetingFor(_at(9), name: '  '), 'Good morning');
    });
  });

  group('her name', () {
    test('the first word of the display name, trimmed', () {
      expect(greetingName('  Nur Aisyah binti Ali '), 'Nur');
      expect(greetingName('Bee'), 'Bee');
    });

    test('long names: at most 14 characters', () {
      expect(greetingName('Nurulhidayahtunnisa Ali'), 'Nurulhidayahtu');
      expect(greetingName('Nurulhidayahtunnisa')!.length, 14);
    });

    test('emoji count as one and are never cut in half', () {
      expect(greetingName('Bee🌸 Tan'), 'Bee🌸');
      final name = greetingName('🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸')!;
      expect(name.characters.length, 14);
      expect(name, '🌸' * 14); // whole flowers only
      expect(greetingName('👩🏽‍🦱Siti'), '👩🏽‍🦱Siti');
    });

    test('no name, or an email: nothing', () {
      expect(greetingName(null), isNull);
      expect(greetingName(''), isNull);
      expect(greetingName('   '), isNull);
      expect(greetingName('bee@example.com'), isNull);
      expect(greetingName('Bee bee@example.com'), isNull);
    });

    test('the name is used only for the greeting on her phone', () {
      // Every place in the app that touches it: the greeting itself, the
      // repository getter, the Discuss hero, and Home passing it along.
      final allowed = {
        'lib/core/utils/greeting.dart',
        'lib/data/repositories/post_repository.dart',
        'lib/presentation/widgets/feed_greeting.dart',
        'lib/presentation/screens/home_screen.dart',
      };
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path.replaceAll('\\', '/');
        final text = file.readAsStringSync();
        if (text.contains('greetingName(') || text.contains('myGreetingName')) {
          expect(allowed, contains(path), reason: path);
        }
      }
      // In the repository it is only read for the getter, never written.
      final repo =
          File('lib/data/repositories/post_repository.dart').readAsStringSync();
      expect('myGreetingName'.allMatches(repo), hasLength(1));
      expect(repo.contains("'displayName'"), isFalse);
      // Home only hands it to the greeting.
      final home =
          File('lib/presentation/screens/home_screen.dart').readAsStringSync();
      expect('myGreetingName'.allMatches(home), hasLength(1));
    });
  });

  group('it fits the 120 px hero on one line (real fonts)', () {
    setUpAll(loadRealFonts);

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (390.0, 2.0)]) {
      for (final name in ['Bee', 'Nurulhidayahtu', null]) {
        testWidgets('${width.round()} px, ${scale}x text, name: $name', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
              home: Scaffold(
                body: Column(
                  children: [FeedGreeting(now: _at(19), name: name)],
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          final text = tester.widget<Text>(
            find.byKey(const ValueKey('greeting')),
          );
          expect(text.maxLines, 1);
          final size = tester.getSize(find.byKey(const ValueKey('greeting')));
          final line = 28 * FeedGreeting.maxTextScale * 1.1;
          expect(size.height, lessThan(line * 1.5)); // one line
          expect(
            tester.getSize(find.byType(HeroCard)).height,
            lessThanOrEqualTo(FeedGreeting.heroHeight + 0.5),
          );
        });
      }
    }

    testWidgets('late at night: the quieter night painting and greeting', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(children: [FeedGreeting(now: _at(23), name: 'Bee')]),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Take a breath, Bee.'), findsOneWidget);
      expect(
        tester.widget<HeroCard>(find.byType(HeroCard)).scene,
        HeroScene.night,
      );
    });
  });
}
