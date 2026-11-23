import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/community.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/home_screen.dart';

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

Future<_FakeRepo> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo();
  await tester.pumpWidget(
    Provider<PostRepository>.value(
      value: repo,
      child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder get _feed => find.byType(Scrollable).first;

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(_feed).position.pixels;

void main() {
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
}
