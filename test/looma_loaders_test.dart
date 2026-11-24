import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/me/post_list_screen.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';
import 'package:women_community_support/presentation/widgets/looma_cat_blink.dart';
import 'package:women_community_support/presentation/widgets/looma_loader.dart';
import 'package:women_community_support/presentation/widgets/paw_loader.dart';

import 'support/real_fonts.dart';

Widget _app(
  Widget child, {
  bool reduceMotion = false,
  bool dark = false,
  double textScale = 1,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  builder:
      (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: c!,
      ),
  home: Scaffold(body: Center(child: child)),
);

/// How visible the closed-eyes frame is (0 = eyes open).
double _closed(WidgetTester tester, {int index = 0}) =>
    tester
        .widgetList<Opacity>(find.byKey(const ValueKey('cat-closed-eyes')))
        .elementAt(index)
        .opacity;

/// Steps through [total] in 25 ms frames; true if the eyes closed at all.
Future<bool> _blinkedWithin(WidgetTester tester, Duration total) async {
  var blinked = false;
  for (var t = 0; t < total.inMilliseconds; t += 25) {
    await tester.pump(const Duration(milliseconds: 25));
    if (_closed(tester) > 0) blinked = true;
  }
  return blinked;
}

void main() {
  group('the picture files', () {
    for (final (path, width, height, limitKb) in [
      (LoomaCatBlink.openAsset, 600, 756, 120),
      (LoomaCatBlink.closedAsset, 600, 756, 120),
      (LoomaLoader.ballAsset, 400, 400, 60),
      (CardPictures.yarnFull, 600, 571, 100),
    ]) {
      testWidgets('$path: real WebP, $width px, under $limitKb KB', (
        tester,
      ) async {
        final file = File(path);
        expect(file.lengthSync(), lessThan(limitKb * 1024));
        final bytes = file.readAsBytesSync();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
        final image =
            (await tester.runAsync(() async {
              final codec = await ui.instantiateImageCodec(bytes);
              return (await codec.getNextFrame()).image;
            }))!;
        expect(image.width, width);
        expect(image.height, height);
        final data =
            (await tester.runAsync(
              () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
            ))!;
        // Transparent background: a corner is clear.
        expect(data.getUint8(3), 0);
      });
    }

    test('the original PNGs are gone', () {
      for (final path in [
        'assets/images/blink_frames/looma_cat_open.png',
        'assets/images/blink_frames/looma_cat_closed.png',
        'assets/images/yarn_pack/yarn_ball_only.png',
        'assets/images/yarn_pack/yarn_full_clean.png',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }
    });
  });

  group('LoomaCatBlink', () {
    testWidgets('eyes open, then a short blink 3 to 5 seconds later', (
      tester,
    ) async {
      await tester.pumpWidget(_app(LoomaCatBlink(random: math.Random(1))));
      expect(_closed(tester), 0);
      // Never before 3 s.
      expect(await _blinkedWithin(tester, const Duration(seconds: 3)), false);
      // Within the next 2 s it blinks, and the blink is short.
      var closedFor = 0;
      for (var t = 0; t < 2000; t += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        if (_closed(tester) > 0) closedFor += 10;
      }
      expect(closedFor, greaterThan(0));
      expect(closedFor, lessThanOrEqualTo(160));
      expect(LoomaCatBlink.pendingTimers, 1); // the next blink is planned
    });

    testWidgets('timers are cancelled when it goes away', (tester) async {
      await tester.pumpWidget(_app(LoomaCatBlink(random: math.Random(2))));
      expect(LoomaCatBlink.pendingTimers, 1);
      await tester.pumpWidget(_app(const SizedBox()));
      expect(LoomaCatBlink.pendingTimers, 0);
      // (The test would also fail if any timer were still pending.)
    });

    testWidgets('Reduce motion: open eyes only, no timers', (tester) async {
      await tester.pumpWidget(_app(const LoomaCatBlink(), reduceMotion: true));
      expect(LoomaCatBlink.pendingTimers, 0);
      expect(await _blinkedWithin(tester, const Duration(seconds: 6)), false);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('not visible (TickerMode off): no blinking', (tester) async {
      await tester.pumpWidget(
        _app(const TickerMode(enabled: false, child: LoomaCatBlink())),
      );
      expect(LoomaCatBlink.pendingTimers, 0);
      expect(await _blinkedWithin(tester, const Duration(seconds: 6)), false);
    });

    testWidgets('app in the background: stops; back: blinks again', (
      tester,
    ) async {
      await tester.pumpWidget(_app(LoomaCatBlink(random: math.Random(3))));
      expect(LoomaCatBlink.pendingTimers, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(LoomaCatBlink.pendingTimers, 0);
      expect(await _blinkedWithin(tester, const Duration(seconds: 6)), false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(LoomaCatBlink.pendingTimers, 1);
    });

    testWidgets('two cats on screen: only the newest one blinks', (
      tester,
    ) async {
      await tester.pumpWidget(_app(LoomaCatBlink(random: math.Random(4))));
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoomaCatBlink(height: 60, random: math.Random(4)),
              LoomaCatBlink(height: 60, random: math.Random(5)),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(LoomaCatBlink.pendingTimers, 1);
    });
  });

  group('LoomaLoader', () {
    testWidgets('the ball rolls out and back, turning; the cat tilts', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const LoomaLoader()));
      double ballX() =>
          tester.getCenter(find.byKey(const ValueKey('yarn-ball'))).dx;
      double turn() => tester
          .widget<Transform>(find.byKey(const ValueKey('yarn-ball')))
          .transform
          .getRotation()
          .entry(1, 0);
      double tilt() => tester
          .widget<Transform>(find.byKey(const ValueKey('loader-cat-tilt')))
          .transform
          .getRotation()
          .entry(1, 0);

      final start = ballX();
      await tester.pump(const Duration(milliseconds: 1500)); // half a loop
      final far = ballX();
      expect(far, greaterThan(start + 60)); // rolled across
      expect(turn(), isNot(0)); // and turned
      await tester.pump(const Duration(milliseconds: 750));
      // Passing the middle: the cat tilts, about 6 degrees at most.
      expect(math.asin(tilt().abs()), greaterThan(0.05));
      expect(
        math.asin(tilt().abs()),
        lessThanOrEqualTo(LoomaLoader.maxTilt + 0.001),
      );
      await tester.pump(const Duration(milliseconds: 750));
      expect(ballX(), closeTo(start, 1)); // and back: a 3 s loop
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('Reduce motion: a still picture of the cat and the ball', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const LoomaLoader(), reduceMotion: true));
      final x = tester.getCenter(find.byKey(const ValueKey('yarn-ball'))).dx;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getCenter(find.byKey(const ValueKey('yarn-ball'))).dx, x);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(LoomaCatBlink.pendingTimers, 0);
    });

    testWidgets('one animated cat: the loader cat takes over', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoomaCatBlink(height: 40, random: math.Random(6)),
              const LoomaLoader(),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LoomaCatBlink), findsNWidgets(2));
      expect(LoomaCatBlink.pendingTimers, 1);
    });

    group('fits (real fonts)', () {
      setUpAll(loadRealFonts);
      for (final dark in [false, true]) {
        testWidgets('320 px, 2x text, ${dark ? 'dark' : 'light'}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder:
                  (context, c) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: c!,
                  ),
              home: const LoomaLoadingScreen(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.takeException(), isNull);
          final loader = tester.getRect(
            find.byKey(const ValueKey('looma-loader')),
          );
          expect(loader.left, greaterThanOrEqualTo(0));
          expect(loader.right, lessThanOrEqualTo(320));
          // The ball stays inside the picture all the way.
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 250));
            final ball = tester.getRect(
              find.byKey(const ValueKey('yarn-ball')),
            );
            expect(ball.right, lessThanOrEqualTo(loader.right + 6));
          }
        });
      }
    });
  });

  group('PawLoader (small spots)', () {
    testWidgets('48 px; the prints appear one after another', (tester) async {
      await tester.pumpWidget(_app(const PawLoader()));
      expect(
        tester.getSize(find.byKey(const ValueKey('paw-loader'))),
        const Size(48, 48),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      // At each moment, earlier prints are at least as visible as later.
      for (final t in [0.1, 0.3, 0.5, 0.7]) {
        final o = [
          for (var i = 0; i < PawLoader.prints; i++) PawLoader.opacityAt(i, t),
        ];
        for (var i = 1; i < o.length; i++) {
          expect(o[i - 1], greaterThanOrEqualTo(o[i]));
        }
      }
      expect(PawLoader.opacityAt(0, 0.3), greaterThan(0));
      expect(PawLoader.opacityAt(3, 0.3), 0);
      expect(PawLoader.opacityAt(3, 0.8), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce motion: still prints, nothing moving', (tester) async {
      await tester.pumpWidget(
        _app(const PawLoader(), reduceMotion: true, dark: true),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets('no saved posts: the yarn ball and a warm line', (tester) async {
    await tester.pumpWidget(
      _app(
        PostListScreen(
          title: 'Saved posts',
          load: () async => [],
          emptyMessage: 'Nothing saved yet.',
          emptyPicture: (CardPictures.yarnFull, CardPictures.yarnFullAspect),
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('empty-cat')),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as AssetImage).assetName, CardPictures.yarnFull);
    expect(find.text('Nothing saved yet.'), findsOneWidget);
    // And Me uses it for Saved posts.
    expect(
      File('lib/presentation/screens/profile_screen.dart').readAsStringSync(),
      contains('CardPictures.yarnFull'),
    );
  });
}
