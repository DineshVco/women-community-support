// Draws a few screens to PNG files, as on an iPhone (390 x 844), light and
// dark, with the real fonts and pictures. Not part of the test suite; for
// before/after pictures of design changes:
//
//   flutter test --update-goldens tool/screenshots.dart
//
// The pictures land in tool/screenshots/ (not committed).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/microcopy.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';
import 'package:women_community_support/presentation/screens/create_post_screen.dart';
import 'package:women_community_support/presentation/screens/me/post_list_screen.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';

import '../test/support/real_fonts.dart';

/// Loads every picture on screen, then lets entrances finish.
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget Function() screen, {
  bool dark = false,
  double textScale = 1,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: screen(),
      ),
    ),
  );
  await _settle(tester);
  final mode = dark ? 'dark' : 'light';
  final size = textScale == 1 ? '' : '_${width.round()}px_${textScale}x';
  await expectLater(
    find.byKey(const ValueKey('shot')),
    matchesGoldenFile('screenshots/${name}_$mode$size.png'),
  );
}

Future<void> _loadIconFonts() async {
  for (final (family, file) in [
    ('packages/phosphor_flutter/PhosphorRegular', 'Phosphor.ttf'),
    ('packages/phosphor_flutter/PhosphorFill', 'Phosphor-Fill.ttf'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('packages/phosphor_flutter/lib/fonts/$file'));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await _loadIconFonts();
  });

  for (final dark in [false, true]) {
    testWidgets('welcome', (tester) async {
      await _shoot(
        tester,
        'welcome',
        () => OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
        dark: dark,
      );
    });

    testWidgets('new post', (tester) async {
      await _shoot(
        tester,
        'new_post',
        () => const CreatePostScreen(),
        dark: dark,
      );
    });

    testWidgets('new poll', (tester) async {
      await _shoot(
        tester,
        'new_poll',
        () => const CreatePostScreen(startAsPoll: true),
        dark: dark,
      );
    });

    testWidgets('my posts (empty)', (tester) async {
      await _shoot(
        tester,
        'my_posts',
        () => PostListScreen(
          title: 'My posts',
          load: () async => [],
          note:
              'Only you can see this list. Others only ever see a random alias.',
          emptyMessage: Microcopy.emptyMyPosts,
          offerWrite: true,
        ),
        dark: dark,
      );
    });

    testWidgets('saved posts (empty)', (tester) async {
      await _shoot(
        tester,
        'saved_posts',
        () => PostListScreen(
          title: 'Saved posts',
          load: () async => [],
          emptyMessage: Microcopy.emptySaved,
          emptyPicture: (CardPictures.yarnFull, CardPictures.yarnFullAspect),
        ),
        dark: dark,
      );
    });
  }

  testWidgets('welcome, 320 px, 2x text', (tester) async {
    await _shoot(
      tester,
      'welcome',
      () => OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
      width: 320,
      textScale: 2,
    );
  });
}
