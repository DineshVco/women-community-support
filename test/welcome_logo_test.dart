import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/widgets/welcome_logo.dart';

import 'support/real_fonts.dart';

final _logo = find.byKey(const ValueKey('welcome-logo'));

Future<void> _pumpLogin(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  bool dark = false,
  bool reduceMotion = false,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
      home: const LoginScreen(),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Decodes [path] and returns (image, raw RGBA bytes).
Future<(ui.Image, ByteData)> _decode(WidgetTester tester, String path) async {
  final bytes = File(path).readAsBytesSync();
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
  final image =
      (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        return (await codec.getNextFrame()).image;
      }))!;
  final data =
      (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
  return (image, data);
}

void main() {
  group('the logo files', () {
    for (final path in [WelcomeLogo.asset, WelcomeLogo.darkAsset]) {
      testWidgets('$path: real WebP, 1000 px wide, under 200 KB, transparent', (
        tester,
      ) async {
        expect(File(path).lengthSync(), lessThan(200 * 1024));
        final (image, data) = await _decode(tester, path);
        expect(image.width, 1000);
        expect(image.width / image.height, closeTo(WelcomeLogo.aspect, 0.01));
        int alpha(int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);
        // The old white frame round the edge is gone: all four corners and
        // the middle of each edge are clear.
        final w = image.width - 1, h = image.height - 1;
        for (final (x, y) in [
          (0, 0),
          (w, 0),
          (0, h),
          (w, h),
          (w ~/ 2, 0),
          (0, h ~/ 2),
          (w, h ~/ 2),
        ]) {
          expect(alpha(x, y), 0, reason: '($x, $y)');
        }
      });
    }

    testWidgets('dark copy: the lettering is light, the cat is the same', (
      tester,
    ) async {
      final (light, lightData) = await _decode(tester, WelcomeLogo.asset);
      final (_, darkData) = await _decode(tester, WelcomeLogo.darkAsset);
      double brightness(ByteData d, int x, int y) {
        final i = (y * light.width + x) * 4;
        return (d.getUint8(i) + d.getUint8(i + 1) + d.getUint8(i + 2)) / 3;
      }

      // Average brightness of solid pixels in a band.
      double band(ByteData d, double from, double to) {
        var sum = 0.0, n = 0;
        for (
          var y = (light.height * from).round();
          y < light.height * to;
          y += 2
        ) {
          for (var x = 0; x < light.width; x += 2) {
            if (d.getUint8((y * light.width + x) * 4 + 3) > 240) {
              sum += brightness(d, x, y);
              n++;
            }
          }
        }
        return sum / n;
      }

      // The name (bottom band): brown in the light logo, cream in the dark.
      expect(band(lightData, 0.84, 0.95), lessThan(140));
      expect(band(darkData, 0.84, 0.95), greaterThan(190));
      // The cat (top half) is unchanged.
      expect(band(darkData, 0.1, 0.5), closeTo(band(lightData, 0.1, 0.5), 3));
    });

    test('the old line cat is gone', () {
      expect(File('assets/images/hero/cat_elegant.webp').existsSync(), isFalse);
    });
  });

  group('only where there is room', () {
    test('a tall phone: large; short phone, big text or keyboard: hidden', () {
      double h(double screen, {double scale = 1, double keyboard = 0}) =>
          WelcomeLogo.heightFor(
            screenHeight: screen,
            textScale: scale,
            keyboard: keyboard,
          );
      expect(h(932), WelcomeLogo.maxHeight);
      expect(h(844), inInclusiveRange(WelcomeLogo.minHeight, 204));
      expect(h(568), 0); // small phone
      expect(h(667), 0); // iPhone SE: the form comes first
      expect(h(932, scale: 2), 0);
      expect(h(932, keyboard: 300), 0);
    });
  });

  group('the sign-in screen (real fonts)', () {
    setUpAll(loadRealFonts);

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';

      testWidgets('320 px, 2x text, $mode: no overflow, logo hidden', (
        tester,
      ) async {
        await _pumpLogin(
          tester,
          size: const Size(320, 568),
          textScale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(_logo, findsNothing);
        // The email box is fully on the first screen, below the bar with
        // Quick exit, without scrolling.
        expect(
          tester.getRect(find.byType(EditableText).first).bottom,
          lessThanOrEqualTo(568),
        );
      });

      testWidgets('320 px, 1x text, $mode: no overflow', (tester) async {
        await _pumpLogin(tester, size: const Size(320, 568), dark: dark);
        expect(tester.takeException(), isNull);
        expect(_logo, findsNothing);
      });

      testWidgets('a tall phone, $mode: the logo above the form', (
        tester,
      ) async {
        await _pumpLogin(tester, size: const Size(430, 932), dark: dark);
        expect(tester.takeException(), isNull);
        expect(_logo, findsOneWidget);
        final logo = tester.getRect(_logo);
        expect(logo.height, WelcomeLogo.maxHeight);
        expect(logo.bottom, lessThan(tester.getRect(find.text('Email')).top));
        final image = tester.widget<Image>(
          find.descendant(of: _logo, matching: find.byType(Image)),
        );
        // Cream lettering on the dark background.
        expect(
          (image.image as ResizeImage).imageProvider,
          isA<AssetImage>().having(
            (a) => a.assetName,
            'asset',
            dark ? WelcomeLogo.darkAsset : WelcomeLogo.asset,
          ),
        );
        // Screen readers hear the name once.
        expect(find.bySemanticsLabel('Looma'), findsOneWidget);
      });
    }

    testWidgets('the keyboard opens: the logo steps aside', (tester) async {
      await _pumpLogin(tester, size: const Size(430, 932), keyboard: 320);
      expect(tester.takeException(), isNull);
      expect(_logo, findsNothing);
    });

    testWidgets('Reduce motion: simply there, nothing moving', (tester) async {
      await _pumpLogin(tester, size: const Size(430, 932), reduceMotion: true);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: _logo, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1);
    });
  });
}
