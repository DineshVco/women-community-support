import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/looma_card.dart';
import 'package:women_community_support/presentation/widgets/skeleton.dart';

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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('post skeletons are cards in the shape of a post', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SkeletonPostList(count: 3)));
    expect(find.byKey(const ValueKey('skeleton-post')), findsNWidgets(3));
    expect(find.byType(LoomaCard), findsNWidgets(3));
    // About as tall as a real post card, not a thin line.
    final h = tester.getSize(find.byType(LoomaCard).first).height;
    expect(h, inInclusiveRange(140, 200));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a soft shimmer moves across them', (tester) async {
    await tester.pumpWidget(_app(const SkeletonPostList()));
    expect(find.byKey(const ValueKey('skeleton-shimmer')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce motion: no shimmer, nothing animating', (tester) async {
    await tester.pumpWidget(_app(const SkeletonPostList(), reduceMotion: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('skeleton-shimmer')), findsNothing);
    expect(find.byKey(const ValueKey('skeleton-post')), findsNWidgets(3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('screen readers hear one "Loading", not the shapes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const SkeletonPostList(label: 'Loading discussions')),
    );
    expect(find.bySemanticsLabel('Loading discussions'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('dark mode works too', (tester) async {
    await tester.pumpWidget(
      _app(
        const SkeletonShimmer(
          child: Column(children: [SkeletonPostCard(), SkeletonReply()]),
        ),
        dark: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('skeleton-reply')), findsOneWidget);
  });

  test('the feed, my posts, a post, replies and reports use skeletons', () {
    for (final path in [
      'lib/presentation/screens/home_screen.dart',
      'lib/presentation/screens/me/post_list_screen.dart',
      'lib/presentation/screens/me/my_reports_screen.dart',
      'lib/presentation/screens/moderator_screen.dart',
      'lib/presentation/screens/post_detail_screen.dart',
    ]) {
      final s = File(path).readAsStringSync();
      expect(s, contains('Skeleton'), reason: path);
    }
    // Home and my posts have no spinner left at all.
    for (final path in [
      'lib/presentation/screens/home_screen.dart',
      'lib/presentation/screens/me/post_list_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('CircularProgressIndicator')),
        reason: path,
      );
    }
  });
}
