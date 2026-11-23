import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/microcopy.dart';
import 'package:women_community_support/presentation/widgets/empty_state.dart';
import 'package:women_community_support/presentation/widgets/living_cat.dart';

Widget _app(Widget child, {bool reduceMotion = false, bool dark = false}) =>
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder:
          (context, c) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: c!,
          ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('the lines come from content/microcopy.json', () {
    final file = File('content/microcopy.json').readAsStringSync();
    final empty =
        (jsonDecode(file) as Map<String, dynamic>)['empty']
            as Map<String, dynamic>;

    test('the built-in copies are the same as the file', () {
      expect(Microcopy.builtInEmpty, empty.cast<String, String>());
    });

    test('feed, search, saved and my posts each have one line', () {
      expect(Microcopy.emptyFeed, empty['feed']);
      expect(Microcopy.emptySearch, empty['search']);
      expect(Microcopy.emptySaved, empty['saved']);
      expect(Microcopy.emptyMyPosts, empty['my_posts']);
    });

    test('the file is bundled with the app', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- ${Microcopy.asset}'),
      );
    });

    test('Najwa can change a line; a missing one falls back', () {
      final lines = Microcopy.parseEmpty(
        '{"empty": {"feed": "  Quiet for now.  ", "search": ""}}',
      );
      expect(lines['feed'], 'Quiet for now.');
      expect(lines['search'], Microcopy.builtInEmpty['search']);
      expect(lines['saved'], Microcopy.builtInEmpty['saved']);
    });
  });

  group('the cat and one warm line', () {
    testWidgets('shows the cat, the line and the button', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _app(
          CatEmptyState(
            line: Microcopy.emptyFeed,
            actionLabel: 'Write a post',
            onAction: () => tapped++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('empty-cat')), findsOneWidget);
      expect(find.byType(LivingCat), findsOneWidget);
      expect(find.text(Microcopy.emptyFeed), findsOneWidget);
      await tester.tap(find.text('Write a post'));
      expect(tapped, 1);
    });

    testWidgets('screen readers hear the line, not the picture', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(CatEmptyState(line: Microcopy.emptySaved), reduceMotion: true),
      );
      expect(find.bySemanticsLabel(Microcopy.emptySaved), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Reduce motion: everything is simply there and still', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(CatEmptyState(line: Microcopy.emptySearch), reduceMotion: true),
      );
      await tester.pump();
      expect(find.text(Microcopy.emptySearch), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('dark mode and 2x text at 320 px: no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder:
              (context, c) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: c!,
              ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CatEmptyState(
                line: Microcopy.emptySaved,
                actionLabel: 'Write a post',
                onAction: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
