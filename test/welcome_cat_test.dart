import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/widgets/welcome_cat.dart';

import 'support/real_fonts.dart';

final _cat = find.byKey(const ValueKey('welcome-cat'));

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

void main() {
  group('the picture file', () {
    testWidgets('a real WebP, 900 px tall, under 100 KB, transparent', (
      tester,
    ) async {
      final file = File(WelcomeCat.asset);
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
      expect(image.height, 900);
      expect(image.width / image.height, closeTo(WelcomeCat.aspect, 0.01));
      final data =
          (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
      int alpha(int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);
      // The paper is gone: corners and the middle of the body are clear.
      expect(alpha(0, 0), 0);
      expect(alpha(image.width - 1, image.height - 1), 0);
      expect(alpha(image.width ~/ 2, image.height ~/ 2), 0);
      // And there are lines.
      var lines = 0;
      for (var i = 3; i < data.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 200) lines++;
      }
      expect(lines, greaterThan(1000));
    });
  });

  group('only where there is room', () {
    test('a tall phone: large; short phone, big text or keyboard: hidden', () {
      double h(double screen, {double scale = 1, double keyboard = 0}) =>
          WelcomeCat.heightFor(
            screenHeight: screen,
            textScale: scale,
            keyboard: keyboard,
          );
      expect(h(932), WelcomeCat.maxHeight);
      expect(h(844), inInclusiveRange(WelcomeCat.minHeight, 204));
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

      testWidgets('320 px, 2x text, $mode: no overflow, cat hidden', (
        tester,
      ) async {
        await _pumpLogin(
          tester,
          size: const Size(320, 568),
          textScale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(_cat, findsNothing);
        // The form starts at the top, so the email field is right there.
        expect(tester.getRect(find.text('Email')).top, lessThan(400));
      });

      testWidgets('320 px, 1x text, $mode: no overflow', (tester) async {
        await _pumpLogin(tester, size: const Size(320, 568), dark: dark);
        expect(tester.takeException(), isNull);
        expect(_cat, findsNothing);
      });

      testWidgets('a tall phone, $mode: the large quiet cat above the form', (
        tester,
      ) async {
        await _pumpLogin(tester, size: const Size(430, 932), dark: dark);
        expect(tester.takeException(), isNull);
        expect(_cat, findsOneWidget);
        final cat = tester.getRect(_cat);
        expect(cat.height, WelcomeCat.maxHeight);
        expect(cat.bottom, lessThan(tester.getRect(find.text('Email')).top));
        final image = tester.widget<Image>(
          find.descendant(of: _cat, matching: find.byType(Image)),
        );
        // Dark lines on light; soft cream lines on dark.
        expect(
          image.color,
          dark
              ? WelcomeCat.darkLine
              : tester.element(_cat).palette.textSecondary,
        );
        expect(image.colorBlendMode, BlendMode.srcIn);
        // Screen readers skip it.
        expect(
          find.ancestor(of: _cat, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
      });
    }

    testWidgets('the keyboard opens: the cat steps aside', (tester) async {
      await _pumpLogin(tester, size: const Size(430, 932), keyboard: 320);
      expect(tester.takeException(), isNull);
      expect(_cat, findsNothing);
    });

    testWidgets('Reduce motion: simply there, nothing moving', (tester) async {
      await _pumpLogin(tester, size: const Size(430, 932), reduceMotion: true);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: _cat, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1);
    });
  });
}
