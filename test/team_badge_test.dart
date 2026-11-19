import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/comment.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/presentation/widgets/comment_tile.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';
import 'package:women_community_support/presentation/widgets/post_card.dart';
import 'package:women_community_support/presentation/widgets/team_badge.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: ListView(children: [child])),
);

Post _post(String alias) => Post(
  id: 'starter_01',
  alias: alias,
  categoryId: 'health_wellness',
  title: 'Welcome to Looma',
  content: 'Say hello and tell us what brought you here.',
  timestamp: DateTime.now().subtract(const Duration(hours: 3)),
);

Comment _reply(String alias) => Comment(
  id: 'c1',
  postId: 'starter_01',
  alias: alias,
  content: 'Glad you are here.',
  timestamp: DateTime.now(),
);

/// The badge is the bordered "Looma Team" tag, not the alias text itself.
final _badge = find.byType(TeamBadge);

void main() {
  test('only the exact team alias counts as the team', () {
    expect(LoomaTeam.isTeam('Looma Team'), isTrue);
    expect(LoomaTeam.isTeam('Quiet Fox'), isFalse);
    expect(LoomaTeam.isTeam('looma team'), isFalse);
  });

  testWidgets('feed: badge next to "Looma Team", none for members', (
    tester,
  ) async {
    // A 390-point phone: the badge must fit beside the counts.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(PostCard(post: _post('Looma Team'))));
    expect(_badge, findsOneWidget);
    expect(find.text('Looma Team'), findsNWidgets(2)); // alias + badge
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(PostCard(post: _post('Quiet Fox'))));
    expect(_badge, findsNothing);
  });

  testWidgets('replies: badge next to "Looma Team", none for members', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(CommentTile(comment: _reply('Looma Team'), isAuthor: true)),
    );
    expect(_badge, findsOneWidget);
    expect(find.text('Original poster'), findsOneWidget);

    await tester.pumpWidget(
      _app(CommentTile(comment: _reply('Gentle Heron'), isAuthor: false)),
    );
    expect(_badge, findsNothing);
  });

  testWidgets('post detail line: alias, badge, time', (tester) async {
    await tester.pumpWidget(
      _app(
        const AliasLine(
          alias: 'Looma Team',
          text: 'Looma Team',
          trailing: ' · 3h',
        ),
      ),
    );
    expect(_badge, findsOneWidget);
    expect(find.text(' · 3h'), findsOneWidget);
  });

  testWidgets('Home shows the starter line only while team posts are there', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(FeedGreeting(posts: [_post('Looma Team'), _post('Quiet Fox')])),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Starter posts to begin the conversation. Add yours.'),
      findsOneWidget,
    );

    await tester.pumpWidget(_app(FeedGreeting(posts: [_post('Quiet Fox')])));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(LoomaTeam.starterLine), findsNothing);
  });
}
