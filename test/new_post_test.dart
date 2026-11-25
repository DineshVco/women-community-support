import 'dart:ui' show SemanticsFlag;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_icons.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/theme/app_typography.dart';
import 'package:women_community_support/presentation/screens/create_post_screen.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

import 'support/real_fonts.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool poll = false,
  bool dark = false,
  double width = 390,
  double height = 844,
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: CreatePostScreen(startAsPoll: poll),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

double _buttonOpacity(WidgetTester tester) =>
    tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('post-button')))
        .opacity;

Finder _chip(String id) => find.byKey(ValueKey('category-$id'));

void main() {
  setUpAll(loadRealFonts);

  testWidgets('nothing chosen at first; a chosen chip is filled with a check', (
    tester,
  ) async {
    await _pump(tester);
    final health = find.bySemanticsLabel('Health & Wellness');
    expect(
      tester.getSemantics(health).hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );
    // Not chosen: the category's own icon, a light wash of its colour.
    expect(
      find.descendant(
        of: _chip('health_wellness'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsNothing,
    );
    await tester.tap(_chip('health_wellness'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getSemantics(health).hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    expect(
      find.descendant(
        of: _chip('health_wellness'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    final box =
        tester.widget<AnimatedContainer>(_chip('health_wellness')).decoration!
            as BoxDecoration;
    expect(box.color, AppPalette.light.categoryFill('health_wellness'));
  });

  testWidgets('Post without a category: a gentle "Choose a category"', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('post-title')), 'Hello');
    await tester.enterText(find.byKey(const ValueKey('post-story')), 'Hi all');
    await tester.tap(find.byKey(const ValueKey('post-button')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(CreatePostScreen.chooseCategory), findsOneWidget);
    // Gentle: the quiet grey, not the red of an error.
    final hint = tester.widget<Text>(
      find.text(CreatePostScreen.chooseCategory),
    );
    expect(hint.style?.color, AppPalette.light.textSecondary);
    // Choosing one makes it go away.
    await tester.tap(_chip('education'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(CreatePostScreen.chooseCategory), findsNothing);
  });

  testWidgets('the Post button is faded until category, title and story', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_buttonOpacity(tester), lessThan(1));
    await tester.tap(_chip('career_development'));
    await tester.enterText(find.byKey(const ValueKey('post-title')), 'A title');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_buttonOpacity(tester), lessThan(1));
    await tester.enterText(
      find.byKey(const ValueKey('post-story')),
      'My story',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_buttonOpacity(tester), 1);
  });

  testWidgets('a poll needs its question and 2 answers', (tester) async {
    await _pump(tester, poll: true);
    await tester.tap(_chip('personal_safety'));
    await tester.enterText(find.byKey(const ValueKey('post-title')), 'Safe?');
    await tester.enterText(find.byKey(const ValueKey('poll-option-0')), 'Yes');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_buttonOpacity(tester), lessThan(1));
    await tester.enterText(find.byKey(const ValueKey('poll-option-1')), 'No');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_buttonOpacity(tester), 1);
  });

  testWidgets('title in Newsreader, story in Figtree; warm focus colour', (
    tester,
  ) async {
    await _pump(tester);
    final title = tester.widget<TextField>(
      find.byKey(const ValueKey('post-title')),
    );
    final story = tester.widget<TextField>(
      find.byKey(const ValueKey('post-story')),
    );
    expect(title.style?.fontFamily, AppTypography.headingFont);
    expect(story.style?.fontFamily, AppTypography.bodyFont);
    final focus = title.decoration!.focusedBorder as OutlineInputBorder;
    expect(focus.borderSide.color, AppPalette.light.accent);
  });

  testWidgets('counters show only near the limit', (tester) async {
    await _pump(tester);
    expect(find.text('0/120'), findsNothing);
    expect(find.text('0/5000'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('post-title')), 'x' * 95);
    await tester.pump();
    expect(find.text('95/120'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('post-title')), 'x' * 100);
    await tester.pump();
    expect(find.text('100/120'), findsOneWidget);
  });

  testWidgets('the privacy note: a soft card with a lock', (tester) async {
    await _pump(tester);
    final note = find.byKey(const ValueKey('privacy-note'));
    expect(
      find.descendant(of: note, matching: find.byIcon(AppIcons.lock)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: note, matching: find.text(CreatePostScreen.postNote)),
      findsOneWidget,
    );
    final box = tester.widget<Container>(note).decoration! as BoxDecoration;
    expect(box.color, AppPalette.light.chipFill);
  });

  testWidgets('the Post button stays above the keyboard', (tester) async {
    await _pump(tester, keyboard: 320);
    final button = tester.getRect(find.text('Post').last);
    expect(button.bottom, lessThanOrEqualTo(844 - 320));
    expect(find.byType(QuickExitButton), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final poll in [false, true]) {
      testWidgets('320 px, 2x text, ${dark ? 'dark' : 'light'}, '
          '${poll ? 'poll' : 'post'}: no overflow, Post on screen', (
        tester,
      ) async {
        await _pump(
          tester,
          poll: poll,
          dark: dark,
          width: 320,
          height: 640,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        final button = tester.getRect(
          find.byKey(const ValueKey('post-button')),
        );
        expect(button.bottom, lessThanOrEqualTo(640));
        expect(button.right, lessThanOrEqualTo(320));
      });
    }
  }
}
