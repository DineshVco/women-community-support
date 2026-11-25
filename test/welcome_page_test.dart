import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';
import 'package:women_community_support/presentation/widgets/looma_cat_blink.dart';
import 'package:women_community_support/presentation/widgets/looma_character.dart';

import 'support/real_fonts.dart';

const _features = {
  'Share Without Your Name':
      'A random alias, never your name. Other members can’t see who you are.',
  'Browse by Category': 'Explore discussions on topics that matter to you',
  'Be Part of a Community': 'Connect with women who understand',
  'Report What Feels Wrong': 'Moderators review reports to keep Looma kind.',
};

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, height);
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
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('the painted Looma cat, no line drawing, no box', (tester) async {
    await _pump(tester, dark: true);
    expect(find.byKey(const ValueKey('welcome-cat')), findsOneWidget);
    expect(find.byType(LoomaCatBlink), findsOneWidget);
    expect(find.byType(LoomaCharacter), findsNothing);
    expect(find.text('A community support app for women'), findsOneWidget);
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    for (final dark in [false, true]) {
      testWidgets('${width.round()} px, ${scale}x text, '
          '${dark ? 'dark' : 'light'}: every feature sentence is whole', (
        tester,
      ) async {
        await _pump(tester, width: width, textScale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        // The logo stays on one line ("Looma", never "Loo / ma").
        final logo = tester.getSize(find.text('Looma').first);
        expect(logo.height, lessThan(80));

        // Scroll the welcome page to its end: every title and sentence is
        // fully above the page dots, with no "..." anywhere.
        final page = find.byType(SingleChildScrollView).first;
        await tester.drag(page, const Offset(0, -3000));
        await tester.pump(const Duration(seconds: 1));
        final dots = tester.getRect(find.bySemanticsLabel('Page 1 of 4'));
        for (final MapEntry(key: title, value: text) in _features.entries) {
          for (final part in [title, text]) {
            final found = find.text(part);
            expect(found, findsOneWidget, reason: part);
            final rect = tester.getRect(found);
            expect(rect.bottom, lessThan(dots.top), reason: part);
            expect(rect.right, lessThanOrEqualTo(width), reason: part);
            final widget = tester.widget<Text>(found);
            expect(widget.maxLines, isNull, reason: part);
            expect(widget.overflow, isNot(TextOverflow.ellipsis));
          }
        }
      });
    }
  }

  test('one warm dark palette, AA text on every dark surface', () {
    const dark = AppPalette.dark;
    expect(dark.background, const Color(0xFF1C1614));
    expect(OnboardingScreen.darkBackground.last, dark.background);
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final bg in [
      dark.background,
      dark.surface,
      dark.softFill,
      ...OnboardingScreen.darkBackground,
    ]) {
      for (final fg in [dark.text, dark.textSecondary, dark.textMuted]) {
        expect(
          contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$fg on $bg',
        );
      }
    }
  });
}
