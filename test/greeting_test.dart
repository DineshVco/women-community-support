import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/greeting.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';
import 'package:women_community_support/presentation/widgets/hero_card.dart';

import 'support/real_fonts.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);

void main() {
  group('the greeting, by local time', () {
    test('three slots with her name, and every boundary', () {
      String g(int h, [int m = 0]) => greetingFor(_at(h, m), name: 'Bee');
      // Morning 05:00-11:59.
      expect(g(5), 'Good morning, Bee');
      expect(g(11, 59), 'Good morning, Bee');
      // Afternoon 12:00-17:59.
      expect(g(12), 'Good afternoon, Bee');
      expect(g(17, 59), 'Good afternoon, Bee');
      // Evening 18:00-04:59.
      expect(g(18), 'Good evening, Bee');
      expect(g(23, 59), 'Good evening, Bee');
      expect(g(0), 'Good evening, Bee');
      expect(g(4, 59), 'Good evening, Bee');
    });

    test('no name (she skipped it): just the greeting', () {
      expect(greetingFor(_at(9)), 'Good morning');
      expect(greetingFor(_at(14)), 'Good afternoon');
      expect(greetingFor(_at(19)), 'Good evening');
      expect(greetingFor(_at(3)), 'Good evening');
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

    test('her chosen name: 1 to 20 characters, never an email', () {
      expect(cleanCallName('  Kak   Ti '), 'Kak Ti');
      expect(cleanCallName('B'), 'B');
      expect(cleanCallName('x' * 20), 'x' * 20);
      expect(cleanCallName('x' * 21), isNull);
      expect(cleanCallName('🌸' * 20), '🌸' * 20); // an emoji counts as one
      expect(cleanCallName(''), isNull);
      expect(cleanCallName('   '), isNull);
      expect(cleanCallName(null), isNull);
      expect(cleanCallName('bee@mail.com'), isNull);
    });

    test('the name is used only for her own greeting', () {
      // Every place in the app that touches it: the greeting, her private
      // profile (read, and written only by setCallName), the sign-up step
      // and the row in Me that change it, and the Discuss hero.
      final allowed = {
        'lib/core/utils/greeting.dart',
        'lib/data/models/user_profile.dart',
        'lib/data/repositories/post_repository.dart',
        'lib/presentation/widgets/feed_greeting.dart',
        'lib/presentation/screens/home_screen.dart',
        'lib/presentation/screens/auth_gate.dart',
        'lib/presentation/screens/membership/membership_flow.dart',
        'lib/presentation/screens/profile_screen.dart',
      };
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path.replaceAll(r'\', '/');
        final text = file.readAsStringSync();
        if (text.contains('greetingName(') ||
            text.contains('GreetingName') ||
            text.contains('callName') ||
            text.contains('CallName')) {
          expect(allowed, contains(path), reason: path);
        }
      }
      // In the repository it is written in one place only: users/{uid}.
      final repo =
          File('lib/data/repositories/post_repository.dart').readAsStringSync();
      expect("'callName'".allMatches(repo), hasLength(1));
      expect(repo.contains("'displayName'"), isFalse);
      final setter = repo
          .replaceAll('\r\n', '\n')
          .substring(repo.replaceAll('\r\n', '\n').indexOf('setCallName('));
      expect(
        setter.substring(0, setter.indexOf('\n  }')),
        contains('_me().set('),
      );
    });
  });

  group('it fits the 120 px hero on one line (real fonts)', () {
    setUpAll(loadRealFonts);

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (390.0, 2.0)]) {
      for (final name in ['Bee', 'Nurulhidayahtu', null]) {
        for (final hour in [19, 23]) {
          testWidgets('${width.round()} px, ${scale}x text, name: $name, '
              '${hour}h', (tester) async {
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
                    children: [FeedGreeting(now: _at(hour), name: name)],
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
            if (hour == 23) {
              // The sleeping cat never covers the greeting.
              expect(
                tester.getRect(find.byKey(const ValueKey('greeting'))).right,
                lessThan(
                  tester
                      .getRect(find.byKey(const ValueKey('sleeping-cat')))
                      .left,
                ),
              );
            }
          });
        }
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
      // Late at night it says good evening (18:00-04:59).
      expect(find.text('Good evening, Bee'), findsOneWidget);
      expect(
        tester.widget<HeroCard>(find.byType(HeroCard)).scene,
        HeroScene.night,
      );
      // The painted cat sleeps in the corner.
      final cat = find.byKey(const ValueKey('sleeping-cat'));
      expect(cat, findsOneWidget);
      final image = tester.widget<Image>(
        find.descendant(of: cat, matching: find.byType(Image)),
      );
      expect((image.image as AssetImage).assetName, CardPictures.catSleep);
      // It stays inside the hero and clear of the greeting.
      final hero = tester.getRect(find.byType(HeroCard));
      final catRect = tester.getRect(cat);
      expect(hero.contains(catRect.topLeft), isTrue);
      expect(hero.contains(catRect.bottomRight - const Offset(1, 1)), isTrue);
      expect(
        tester.getRect(find.byKey(const ValueKey('greeting'))).right,
        lessThan(catRect.left),
      );
    });
  });
}
