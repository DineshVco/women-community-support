import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/hero_card.dart';

/// WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What sits behind the text at [x] over a painting [pixel], layer by layer
/// exactly as HeroCard paints them.
Color _behindText(Brightness brightness, Color pixel, double x) {
  var c = pixel;
  final veil = HeroVeil.colorFor(brightness);
  c = Color.alphaBlend(
    veil.withValues(alpha: HeroVeil.alphaAt(brightness, x)),
    c,
  );
  if (brightness == Brightness.light) {
    // Worst case: the blush wash at full strength.
    c = Color.alphaBlend(
      AppPalette.light.blush.withValues(alpha: HeroVeil.blushWash),
      c,
    );
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
    for (final (name, brightness, text) in [
      ('light', Brightness.light, AppPalette.light.text),
      ('dark', Brightness.dark, AppPalette.dark.text),
    ]) {
      test('$name mode, any painting (night too): over the darkest '
          'and lightest painting, up to the edge of the text', () {
        for (final pixel in const [Color(0xFF000000), Color(0xFFFFFFFF)]) {
          for (var x = 0.0; x <= HeroVeil.textWidth + 1e-9; x += 0.05) {
            final behind = _behindText(brightness, pixel, x);
            expect(
              _contrast(text, behind),
              greaterThanOrEqualTo(4.5),
              reason: 'x=$x over $pixel',
            );
          }
        }
      });
    }

    test('dark mode veils the painting more than light mode', () {
      expect(
        HeroVeil.alphaAt(Brightness.dark, 1),
        greaterThan(HeroVeil.alphaAt(Brightness.light, 1)),
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
    expect(text.right, lessThanOrEqualTo(card.left + card.width * 0.6 + 1));
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
}
