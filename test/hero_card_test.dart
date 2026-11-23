import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';
import 'package:women_community_support/presentation/widgets/hero_card.dart';

import 'support/real_fonts.dart';

/// WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What sits behind the text at [x] over a painting [pixel], layer by layer
/// exactly as HeroCard paints them.
Color _behindText(
  HeroVeil veil,
  Brightness brightness,
  AppPalette p,
  Color pixel,
  double x,
) {
  var c = Color.alphaBlend(
    veil
        .colorAt(brightness, p.discussHeroGradient, x)
        .withValues(alpha: veil.alphaAt(brightness, x)),
    pixel,
  );
  if (brightness == Brightness.light) {
    // Worst case: the blush wash at full strength.
    c = Color.alphaBlend(p.blush.withValues(alpha: HeroVeil.blushWash), c);
  }
  return c;
}

class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.contains('hero/')) throw FlutterError('missing $key');
    return rootBundle.load(key);
  }
}

Widget _app(
  Widget child, {
  ThemeData? theme,
  bool reduceMotion = false,
  double textScale = 1,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: Center(child: child)),
  ),
);

HeroCard _card({VoidCallback? onTap, HeroScene scene = HeroScene.morning}) =>
    HeroCard(
      scene: scene,
      actionLabel: 'Write a post',
      onTap: onTap,
      children: const [Text('Good morning'), Text('You are not alone here.')],
    );

void main() {
  group('which painting', () {
    test('Discuss follows the time of day, like the greeting', () {
      HeroScene at(int h, [int m = 0]) =>
          HeroScene.forTime(DateTime(2026, 11, 23, h, m));
      expect(at(5), HeroScene.morning);
      expect(at(11, 59), HeroScene.morning);
      expect(at(16, 59), HeroScene.morning); // afternoon: daylight scene
      expect(at(17), HeroScene.dusk);
      expect(at(21, 59), HeroScene.dusk);
      expect(at(22), HeroScene.night);
      expect(at(0), HeroScene.night);
      expect(at(4, 59), HeroScene.night);
    });

    test('late at night has its own painting', () {
      expect(HeroScene.night.asset, 'assets/images/hero/hero_night.webp');
      expect(HeroScene.night.asset, isNot(HeroScene.dusk.asset));
    });

    test('the paintings are bundled WebP files under 150 KB', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/images/hero/'));
      for (final scene in HeroScene.values) {
        final file = File(scene.asset);
        expect(file.existsSync(), isTrue, reason: scene.asset);
        expect(scene.asset, endsWith('.webp'));
        expect(file.lengthSync(), lessThan(150 * 1024), reason: scene.asset);
      }
    });
  });

  testWidgets('the card pictures are real WebP files, 1200 px, under 150 KB', (
    tester,
  ) async {
    for (final asset in [CardPictures.magnolia]) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: asset);
      expect(file.lengthSync(), lessThan(150 * 1024), reason: asset);
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
      final width = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        return (await codec.getNextFrame()).image.width;
      });
      expect(width, 1200, reason: asset);
    }
    // No PNG copies left behind, and the old cat picture is gone.
    for (final png in [
      'assets/images/cat_nap.png',
      'assets/images/hero/cat_nap.png',
      'assets/images/hero/hero_cat_grass.webp',
      'assets/images/hero_magnolia.png',
      'assets/images/hero_cat_grass.png',
      'assets/images/hero/hero_magnolia.png',
      'assets/images/hero/hero_cat_grass.png',
    ]) {
      expect(File(png).existsSync(), isFalse, reason: png);
    }
  });

  testWidgets('the napping cat: real WebP, about 800 px, under 100 KB', (
    tester,
  ) async {
    final file = File(CardPictures.catNap);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), lessThan(100 * 1024));
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
    final image =
        (await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(bytes);
          return (await codec.getNextFrame()).image;
        }))!;
    expect(image.width, 800);
    // Clean edges: no faint specks away from the cat. Faint pixels are
    // allowed only right at its outline (the soft edge), within 4 px.
    final data =
        (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
    final w = image.width, h = image.height;
    int alpha(int x, int y) => data.getUint8((y * w + x) * 4 + 3);
    var specks = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final a = alpha(x, y);
        if (a == 0 || a >= 16) continue;
        var nearCat = false;
        for (var dy = -4; dy <= 4 && !nearCat; dy++) {
          for (var dx = -4; dx <= 4 && !nearCat; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx >= 0 &&
                ny >= 0 &&
                nx < w &&
                ny < h &&
                alpha(nx, ny) >= 128) {
              nearCat = true;
            }
          }
        }
        if (!nearCat) specks++;
      }
    }
    expect(specks, 0);
    expect(data.getUint8(3), 0); // top-left corner is clear
  });

  testWidgets('the night painting is a real WebP, at most 1600 px wide', (
    tester,
  ) async {
    final bytes = File(HeroScene.night.asset).readAsBytesSync();
    // "RIFF....WEBP": a real WebP, not a PNG with a .webp name.
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
    final width = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image.width;
    });
    expect(width, inInclusiveRange(1200, 1600));
  });

  group('text stays readable (WCAG AA, 4.5:1)', () {
    for (final (veilName, veil) in [
      ('standard', HeroVeil.standard),
      ('Care', HeroVeil.care),
      ('Discuss', HeroVeil.discuss),
    ]) {
      for (final (name, brightness, p) in [
        ('light', Brightness.light, AppPalette.light),
        ('dark', Brightness.dark, AppPalette.dark),
      ]) {
        test('$veilName, $name: over the darkest and lightest painting, up '
            'to the edge of the text', () {
          for (final pixel in const [Color(0xFF000000), Color(0xFFFFFFFF)]) {
            for (var x = 0.0; x <= veil.textWidth + 1e-9; x += 0.025) {
              expect(
                _contrast(p.text, _behindText(veil, brightness, p, pixel, x)),
                greaterThanOrEqualTo(4.5),
                reason: 'x=$x over $pixel',
              );
            }
          }
        });
      }
    }

    test('the painting shows: each veil is strong only behind the text', () {
      for (final veil in HeroVeil.all) {
        for (final b in Brightness.values) {
          expect(veil.alphaAt(b, veil.textWidth), greaterThanOrEqualTo(0.8));
        }
      }
      // Standard: almost clear on the right in light mode.
      expect(
        HeroVeil.standard.alphaAt(Brightness.light, 1),
        lessThanOrEqualTo(0.05),
      );
      // Care: a 65% text column, and the vase side almost clear.
      expect(HeroVeil.care.textWidth, closeTo(0.65, 0.001));
      expect(
        HeroVeil.care.alphaAt(Brightness.light, 0.9),
        lessThanOrEqualTo(0.06),
      );
      // Discuss: fully clear from 60% to the right edge (light).
      for (var x = 0.6; x <= 1.0001; x += 0.05) {
        expect(
          HeroVeil.discuss.alphaAt(Brightness.light, x),
          0,
          reason: 'x=$x',
        );
      }
      // Dark mode keeps a faint veil against glare.
      expect(
        HeroVeil.discuss.alphaAt(Brightness.dark, 1),
        lessThanOrEqualTo(0.2),
      );
    });
  });

  testWidgets('shows the text on the left; a tap gives a light haptic', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    var taps = 0;
    await tester.pumpWidget(_app(_card(onTap: () => taps++)));
    await tester.pump();

    final card = tester.getRect(find.byType(HeroCard));
    final text = tester.getRect(find.text('You are not alone here.'));
    expect(
      text.right,
      lessThanOrEqualTo(
        card.left + card.width * HeroVeil.standard.textWidth + 1,
      ),
    );
    expect(find.text('Write a post'), findsOneWidget);

    await tester.tap(find.byType(HeroCard));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('rounded 20 px corners', (tester) async {
    await tester.pumpWidget(_app(_card()));
    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(HeroCard),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('a soft gradient shows if the painting cannot load', (
    tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(bundle: _FailingBundle(), child: _app(_card())),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('hero-fallback')), findsWidgets);
    expect(find.text('Good morning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scene in HeroScene.values) {
    testWidgets('${scene.name} in dark mode with large text', (tester) async {
      await tester.pumpWidget(
        _app(_card(scene: scene), theme: AppTheme.dark, textScale: 2),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('with Reduce motion nothing keeps animating', (tester) async {
    await tester.pumpWidget(_app(_card(onTap: () {}), reduceMotion: true));
    await tester.pump();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  group('the Discuss hero with real fonts', () {
    setUpAll(loadRealFonts);

    for (final (name, hour, theme) in [
      ('morning', 9, AppTheme.light),
      ('afternoon', 14, AppTheme.light),
      ('evening', 19, AppTheme.dark),
      ('late night', 23, AppTheme.dark),
    ]) {
      testWidgets('$name: about 120 px, the greeting fits, cat still there', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: FeedGreeting(now: DateTime(2026, 11, 23, hour)),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final hero = tester.getSize(find.byType(HeroCard));
        expect(hero.height, lessThanOrEqualTo(130));
        expect(find.byType(PeekingCat), findsOneWidget);
      });
    }
  });
}
