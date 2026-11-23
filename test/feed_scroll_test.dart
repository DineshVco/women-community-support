import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/greeting.dart';
import 'package:women_community_support/data/models/community.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/home_screen.dart';
import 'package:women_community_support/presentation/widgets/fade_slide_in.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';

import 'support/real_fonts.dart';
import 'package:women_community_support/presentation/widgets/looma_header.dart';
import 'package:women_community_support/presentation/widgets/hero_card.dart';
import 'package:women_community_support/presentation/widgets/looma_card.dart';
import 'package:women_community_support/presentation/widgets/post_card.dart';

// The bug: "after scrolling up and down a few times, the feed gets stuck".
// Cause: the long-press menu on each post (CupertinoContextMenu) floated a
// copy of the post over the app while a finger rested on it. A quick fling
// threw the post out of the list before the copy shrank back, and Flutter
// never removed the copy: an invisible pane that swallowed every touch on
// that spot. These tests drive the real Discuss screen the same way.

class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _NoAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

/// Live in-memory streams instead of Firestore.
class _FakeRepo extends PostRepository {
  _FakeRepo() : super(firestore: _NoDb(), auth: _NoAuth());

  final _updates = StreamController<List<Post>>.broadcast();
  List<Post> posts = _posts();

  @override
  String? get myUid => 'me';

  @override
  String? get myGreetingName => 'Bee';

  @override
  Stream<List<Post>> watchFeed() async* {
    yield posts;
    yield* _updates.stream;
  }

  @override
  Stream<SmallWinsThread?> watchSmallWins() => Stream.value(null);

  @override
  Stream<ThemedWeek?> watchThemedWeek() => Stream.value(null);

  @override
  Stream<bool> watchVoted(String postId) => Stream.value(false);

  void push(List<Post> next) => _updates.add(posts = next);
}

/// Plain posts, polls and Looma Team posts mixed, like the real feed.
List<Post> _posts({int votes = 0}) => [
  for (var i = 0; i < 40; i++)
    Post(
      id: 'p$i',
      alias: i % 5 == 0 ? 'Looma Team' : 'Quiet Fox',
      categoryId: 'health_wellness',
      title: 'Post number $i',
      content: i % 3 == 0 ? '' : 'Some words about this post. ' * 4,
      timestamp: DateTime(2026, 11, 19).subtract(Duration(hours: i)),
      type: i % 3 == 0 ? 'poll' : null,
      options: i % 3 == 0 ? const ['Yes', 'No', 'Sometimes'] : const [],
      voteCounts: i % 3 == 0 ? [votes, 1, 2] : const [],
    ),
];

Future<_FakeRepo> _pumpHome(
  WidgetTester tester, {
  List<Post>? posts,
  bool sixInchPhone = false,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  if (sixInchPhone) {
    // A 6-inch phone: 390 x 844 points, 47 pt status bar, 34 pt home bar.
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  }
  addTearDown(tester.view.reset);
  final repo = _FakeRepo();
  if (posts != null) repo.posts = posts;
  await tester.pumpWidget(
    Provider<PostRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder get _feed => find.byType(Scrollable).first;

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(_feed).position.pixels;

void main() {
  setUpAll(loadRealFonts);

  for (final restMs in [150, 300, 450]) {
    testWidgets('finger rests ${restMs}ms on a post, then flings: the feed '
        'still scrolls from that spot', (tester) async {
      await _pumpHome(tester);
      await tester.drag(_feed, const Offset(0, -600));
      await tester.pumpAndSettle();

      const spot = Offset(195, 500);
      for (var round = 0; round < 3; round++) {
        // Rest on a post (frame by frame, like a phone), then fling it away.
        final finger = await tester.startGesture(spot);
        for (var t = 0; t < restMs; t += 16) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        for (var i = 0; i < 12; i++) {
          await finger.moveBy(Offset(0, round.isEven ? -120 : 120));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await finger.up();
        await tester.pumpAndSettle();
      }

      // Nothing floats over the app, and a drag from the same spot scrolls.
      expect(find.byType(CupertinoActionSheet), findsNothing);
      final before = _offset(tester);
      await tester.dragFrom(spot, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_offset(tester), greaterThan(before));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('many flings up and down while the feed updates live', (
    tester,
  ) async {
    final repo = await _pumpHome(tester);
    for (var round = 0; round < 6; round++) {
      await tester.fling(_feed, const Offset(0, -900), 3000);
      repo.push(_posts(votes: round)); // someone votes somewhere
      await tester.pumpAndSettle();
      await tester.fling(_feed, const Offset(0, 900), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final before = _offset(tester);
    await tester.drag(_feed, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_offset(tester), greaterThan(before));
  });

  testWidgets('press and hold a post still offers Save, Share and Report', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.longPress(find.text('Post number 0'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    final report = tester.widget<CupertinoActionSheetAction>(
      find.widgetWithText(CupertinoActionSheetAction, 'Report'),
    );
    expect(report.isDestructiveAction, isTrue);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('at the end of the feed, "Write a post" covers no card', (
    tester,
  ) async {
    await _pumpHome(tester);
    // Scroll all the way down.
    for (var i = 0; i < 20; i++) {
      await tester.fling(_feed, const Offset(0, -2000), 5000);
      await tester.pumpAndSettle();
    }
    final pill = tester.getRect(find.byType(WritePill));
    final cards = find.byType(LoomaCard);
    final lastBottom = cards
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).bottom)
        .reduce((a, b) => a > b ? a : b);
    expect(lastBottom, lessThanOrEqualTo(pill.top));
  });

  group('design pass 3: a shorter top', () {
    /// Ordinary posts (no polls), as most of the feed is.
    List<Post> plain() => [
      for (var i = 0; i < 10; i++)
        Post(
          id: 'q$i',
          alias: 'Quiet Fox',
          categoryId: 'education',
          title: 'Scholarship tips for first-year students?',
          content: 'Any advice for the first application? ' * 3,
          timestamp: DateTime(2026, 11, 23).subtract(Duration(hours: i)),
          meTooCount: 2,
          commentCount: 1,
        ),
    ];

    testWidgets('at least 1.5 posts show on a 6-inch phone', (tester) async {
      await _pumpHome(tester, posts: plain(), sixInchPhone: true);
      // What she sees: above the tab bar (56 pt) and the home bar.
      const visibleBottom = 844.0 - 34 - 56;
      final cards = [
        for (final e in find.byType(PostCard).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ]..sort((a, b) => a.top.compareTo(b.top));
      final first = cards[0];
      final second = cards[1];
      expect(first.bottom, lessThanOrEqualTo(visibleBottom));
      final shown = (visibleBottom - second.top) / second.height;
      expect(shown, greaterThanOrEqualTo(0.5));
    });

    testWidgets('the hero is about 120 px with the greeting and one line', (
      tester,
    ) async {
      await _pumpHome(tester);
      final hero = tester.getSize(find.byType(HeroCard));
      expect(hero.height, inInclusiveRange(118, 130));
      final texts = find.descendant(
        of: find.byType(HeroCard),
        matching: find.byType(Text),
      );
      expect(texts, findsNWidgets(2)); // greeting + one short line
      expect(
        find.textContaining('new discussion'),
        findsNothing,
      ); // the count left the hero
      expect(find.text(HomeScreen.emptyMessage), findsNothing);
    });

    testWidgets('only the empty feed shows the cat and its warm line', (
      tester,
    ) async {
      // Reduce motion: the empty-state cat would otherwise keep living.
      await _pumpHome(tester, posts: const [], reduceMotion: true);
      expect(
        find.text('Nothing here yet. Be the first to say hello.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('empty-cat')), findsOneWidget);
      expect(find.text('Write a post'), findsWidgets);
    });

    testWidgets('hero and question scroll away; search and filters stay', (
      tester,
    ) async {
      await _pumpHome(tester, sixInchPhone: true);
      await tester.drag(_feed, const Offset(0, -900));
      await tester.pumpAndSettle();
      final filters = tester.getRect(
        find.byKey(const ValueKey('discuss-filters')),
      );
      // Pinned right under the collapsed header (status bar + its 48 px
      // row), still on screen.
      expect(filters.top, closeTo(47 + LoomaHeader.minRow, 1));
      expect(find.text('Search discussions'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      // The hero and the question card have scrolled away.
      expect(find.byType(HeroCard).hitTestable(), findsNothing);
      expect(find.text('Question of the day').hitTestable(), findsNothing);
    });

    testWidgets('a cat peeks in at the hero\'s right edge', (tester) async {
      await _pumpHome(tester);
      final hero = tester.getRect(find.byType(HeroCard));
      final cat = tester.getRect(find.byType(PeekingCat));
      // In the bottom right corner of the hero, over the painting.
      expect(
        hero.contains(cat.topLeft) && hero.contains(cat.bottomRight),
        isTrue,
      );
      expect(cat.center.dx, greaterThan(hero.center.dx));
      expect(cat.center.dy, greaterThan(hero.center.dy));
      // Decorative: screen readers skip it.
      expect(
        find.descendant(
          of: find.byType(PeekingCat),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Reduce motion: the cat is simply there', (tester) async {
      await _pumpHome(tester, reduceMotion: true);
      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(PeekingCat),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
    });
  });

  testWidgets('cards fade up with a short stagger; Reduce motion: none', (
    tester,
  ) async {
    Future<List<double>> opacities(bool reduce) async {
      // A tall screen, so several cards are on it at once.
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<PostRepository>.value(
          value: _FakeRepo(),
          child: MaterialApp(
            theme: AppTheme.light,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: reduce),
                  child: child!,
                ),
            home: const HomeScreen(),
          ),
        ),
      );
      // Wait for the first frame with posts, then 60 ms into the entrance.
      for (var i = 0; i < 20 && find.byType(PostCard).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var t = 0; t < 60; t += 15) {
        await tester.pump(const Duration(milliseconds: 15));
      }
      return tester
          .widgetList<FadeTransition>(
            // Each card's own entrance (FadeSlideIn wraps one card).
            find.descendant(
              of: find.byType(FadeSlideIn),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value)
          .toList();
    }

    final moving = await opacities(false);
    // Mid-entrance: the first card is further along than a later one.
    expect(moving.first, greaterThan(moving.last));
    expect(moving.last, lessThan(1));

    await tester.pumpWidget(const SizedBox());
    final still = await opacities(true);
    expect(still, everyElement(1.0));
  });

  group('"Write a post" stays off poll answers and counts', () {
    bool pillVisible(WidgetTester tester) =>
        !tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('write-pill-gate')),
            )
            .ignoring;

    /// Poll answers and counts rows of cards on screen, found by their keys
    /// (not by the app's own tracking).
    List<Rect> tappableAreas(WidgetTester tester) {
      final screen = Offset.zero & tester.view.physicalSize / 3;
      return [
        for (final e
            in find
                .byWidgetPredicate(
                  (w) =>
                      w.key is ValueKey<String> &&
                      ((w.key! as ValueKey<String>).value.startsWith(
                            'poll-answers-',
                          ) ||
                          (w.key! as ValueKey<String>).value.startsWith(
                            'post-counts-',
                          )),
                )
                .evaluate())
          if (e.renderObject case final RenderBox box
              when box.attached && box.hasSize)
            if ((box.localToGlobal(Offset.zero) & box.size) case final r
                when r.overlaps(screen))
              r,
      ];
    }

    void expectClear(WidgetTester tester, String when) {
      if (!pillVisible(tester)) return; // hidden: nothing to cover
      final pill = tester.getRect(find.byType(WritePill));
      for (final area in tappableAreas(tester)) {
        expect(pill.overlaps(area), isFalse, reason: '$when: $area');
      }
    }

    testWidgets('at the start, while scrolling down and back up', (
      tester,
    ) async {
      // Polls every third post (see _posts), on a 6-inch phone.
      await _pumpHome(tester, sixInchPhone: true);
      expectClear(tester, 'at rest');

      // Scroll down: checked every frame. The pill hides.
      final finger = await tester.startGesture(const Offset(100, 600));
      for (var i = 0; i < 20; i++) {
        await finger.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
        expectClear(tester, 'down $i');
      }
      expect(pillVisible(tester), isFalse);
      await finger.up();
      await tester.pumpAndSettle();
      expectClear(tester, 'stopped');

      // Scroll back up: the pill returns, never on a button.
      final up = await tester.startGesture(const Offset(100, 300));
      for (var i = 0; i < 20; i++) {
        await up.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
        expectClear(tester, 'up $i');
      }
      await up.up();
      await tester.pumpAndSettle();
      expectClear(tester, 'stopped again');
    });

    testWidgets('Reduce motion: it just shows or hides', (tester) async {
      await _pumpHome(tester, sixInchPhone: true, reduceMotion: true);
      final finger = await tester.startGesture(const Offset(100, 600));
      await finger.moveBy(const Offset(0, -60));
      await tester.pump();
      await finger.moveBy(const Offset(0, -60));
      await tester.pump();
      // Hidden at once: no fade still running.
      expect(pillVisible(tester), isFalse);
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(WritePill),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, 0);
      // Scrolling up: back at once, fully shown in one frame.
      await finger.moveBy(const Offset(0, 40));
      await tester.pump();
      await finger.up();
      await tester.pump();
      if (pillVisible(tester)) {
        final shown = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(WritePill),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(shown.opacity, 1);
        final scale = tester.widget<AnimatedScale>(
          find
              .ancestor(
                of: find.byType(WritePill),
                matching: find.byType(AnimatedScale),
              )
              .first,
        );
        expect(scale.duration, Duration.zero); // no animation
      }
    });
  });

  testWidgets('Discuss greets her by her first name', (tester) async {
    await _pumpHome(tester);
    expect(find.text(greetingFor(DateTime.now(), name: 'Bee')), findsOneWidget);
  });
}
