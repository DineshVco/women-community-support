import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';
import 'package:women_community_support/presentation/widgets/floating_illustration.dart';

import 'support/real_fonts.dart';

const _cats = [LoomaCats.share, LoomaCats.browse, LoomaCats.safe];

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
      home: OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
    ),
  );
  await tester.pump();
}

Future<void> _goTo(WidgetTester tester, int page) async {
  tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(page);
  await tester.pumpAndSettle();
}

void main() {
  group('the painted cat files', () {
    for (final asset in _cats) {
      testWidgets('$asset: real WebP, 800 px long side, under 100 KB, clean', (
        tester,
      ) async {
        final file = File(asset);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), lessThan(100 * 1024));
        final bytes = file.readAsBytesSync();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
        final image =
            (await tester.runAsync(() async {
              final codec = await ui.instantiateImageCodec(bytes);
              return (await codec.getNextFrame()).image;
            }))!;
        final w = image.width, h = image.height;
        expect(math.max(w, h), 800);
        expect(w / h, closeTo(LoomaCats.aspect[asset]!, 0.01));
        final data =
            (await tester.runAsync(
              () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
            ))!;
        int alpha(int x, int y) => data.getUint8((y * w + x) * 4 + 3);
        // Transparent around the cat.
        expect(alpha(0, 0), 0);
        expect(alpha(w - 1, 0), 0);
        // No specks: every visible pixel has visible neighbours.
        var specks = 0;
        for (var y = 2; y < h - 2; y++) {
          for (var x = 2; x < w - 2; x++) {
            if (alpha(x, y) == 0) continue;
            var near = 0;
            for (var dy = -2; dy <= 2; dy++) {
              for (var dx = -2; dx <= 2; dx++) {
                if (alpha(x + dx, y + dy) > 0) near++;
              }
            }
            if (near <= 3) specks++;
          }
        }
        expect(specks, 0);
      });
    }

    test('the old line-drawn cats are gone', () {
      for (final name in ['share', 'browse', 'safe']) {
        expect(File('assets/images/looma_cat_$name.png').existsSync(), isFalse);
        expect(
          File('assets/images/onboarding_$name.png').existsSync(),
          isFalse,
        );
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('looma_cat_share')),
      );
    });
  });

  group('same box, same weight, never cropped', () {
    for (final page in [const Size(272, 330), const Size(342, 600)]) {
      test('page ${page.width.round()} x ${page.height.round()}', () {
        final box = IdeaArt.boxFor(page);
        final areas = <double>[];
        for (final asset in _cats) {
          final art = IdeaArt.fit(LoomaCats.aspect[asset]!, box);
          expect(art.width, lessThanOrEqualTo(box.width + 0.01));
          expect(art.height, lessThanOrEqualTo(box.height + 0.01));
          expect(
            art.width / art.height,
            closeTo(LoomaCats.aspect[asset]!, 0.001),
          );
          areas.add(art.width * art.height);
        }
        // Equal weight: the same area for the tall, round and wide cat.
        expect(areas.reduce(math.max) / areas.reduce(math.min), lessThan(1.01));
      });
    }
  });

  group('the background', () {
    test('blush to cream, warm in dark mode, and the text stays AA', () {
      const light = AppPalette.light;
      const dark = AppPalette.dark;
      for (final bg in OnboardingScreen.lightBackground) {
        expect(_contrast(light.text, bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(light.textSecondary, bg), greaterThanOrEqualTo(4.5));
      }
      for (final bg in OnboardingScreen.darkBackground) {
        expect(_contrast(dark.text, bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(dark.textSecondary, bg), greaterThanOrEqualTo(4.5));
        // Warm: more red than blue.
        expect(bg.r, greaterThan(bg.b));
      }
    });
  });

  group('every idea page fits (real fonts)', () {
    setUpAll(loadRealFonts);

    for (final (size, scale) in [
      (const Size(320, 568), 2.0),
      (const Size(320, 568), 1.0),
      (const Size(430, 932), 1.0),
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
          '${size.width.round()} x ${size.height.round()}, ${scale}x text, '
          '${dark ? 'dark' : 'light'}',
          (tester) async {
            await _pump(tester, size: size, textScale: scale, dark: dark);
            expect(tester.takeException(), isNull);
            final background = tester.widget<DecoratedBox>(
              find.byKey(const ValueKey('onboarding-background')),
            );
            expect(
              (background.decoration as BoxDecoration).gradient!.colors,
              dark
                  ? OnboardingScreen.darkBackground
                  : OnboardingScreen.lightBackground,
            );
            for (var i = 0; i < _cats.length; i++) {
              await _goTo(tester, i + 1);
              expect(tester.takeException(), isNull);
              final box = tester.getRect(
                find.byKey(ValueKey('idea-art-${i + 1}')),
              );
              final cat = find.byWidgetPredicate(
                (w) => w is FloatingIllustration && w.asset == _cats[i],
              );
              final image = tester.getRect(
                find.descendant(of: cat, matching: find.byType(Image)),
              );
              // Centred in the box, inside it, and on screen.
              expect(image.center.dx, closeTo(box.center.dx, 1));
              expect(image.center.dy, closeTo(box.center.dy, 1));
              expect(image.left, greaterThanOrEqualTo(box.left - 0.5));
              expect(image.right, lessThanOrEqualTo(box.right + 0.5));
              expect(image.left, greaterThanOrEqualTo(0));
              expect(image.right, lessThanOrEqualTo(size.width));
              // Paintings: no light card behind them in dark mode.
              expect(
                find.descendant(
                  of: cat,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Container &&
                        w.decoration is BoxDecoration &&
                        (w.decoration as BoxDecoration).color ==
                            AppPalette.illustrationCard,
                  ),
                ),
                findsNothing,
              );
            }
          },
        );
      }
    }
  });
}
