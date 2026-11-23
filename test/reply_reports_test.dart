import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/comment.dart';
import 'package:women_community_support/data/models/report.dart';
import 'package:women_community_support/presentation/screens/moderator_screen.dart';
import 'package:women_community_support/presentation/widgets/comment_tile.dart';

Report _report(
  String id, {
  String postId = 'p1',
  String? commentId,
  String reason = 'Harassment or hate',
}) => Report.fromMap(id, {
  'postId': postId,
  if (commentId != null) 'commentId': commentId,
  'postTitle': 'Scholarship tips?',
  'reason': reason,
  'status': 'open',
});

void main() {
  group('reply model', () {
    test('status and flags, visible by default (older replies)', () {
      final old = Comment.fromMap('c1', 'p1', {'alias': 'A', 'content': 'x'});
      expect(old.status, 'visible');
      expect(old.flagCount, 0);
      expect(old.isVisible, isTrue);
      final hidden = Comment.fromMap('c2', 'p1', {
        'alias': 'A',
        'content': 'x',
        'status': 'hidden',
        'flagCount': 3,
      });
      expect(hidden.isVisible, isFalse);
      expect(hidden.flagCount, 3);
    });
  });

  group('reports', () {
    test('a reply report names the reply', () {
      expect(_report('r1').isReply, isFalse);
      final reply = _report('r2', commentId: 'c1');
      expect(reply.isReply, isTrue);
      expect(reply.commentId, 'c1');
    });

    test('the queue keeps a post and each of its replies separate', () {
      final items = ModeratorScreen.group([
        _report('a', reason: 'Spam or advertising'),
        _report('b', commentId: 'c1'),
        _report('c', commentId: 'c1', reason: 'Private information'),
        _report('d', commentId: 'c2'),
      ]);
      expect(items, hasLength(3));
      final reply = items.firstWhere((i) => i.commentId == 'c1');
      expect(reply.isReply, isTrue);
      expect(reply.reasons, hasLength(2));
      expect(items.where((i) => !i.isReply), hasLength(1));
      expect(items.map((i) => i.key).toSet(), {'p1', 'p1/c1', 'p1/c2'});
    });
  });

  testWidgets('a reply has a Report button (44 px to tap)', (tester) async {
    var reported = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CommentTile(
            comment: Comment.fromMap('c1', 'p1', {
              'alias': 'Gentle Heron',
              'content': 'Same here.',
            }),
            isAuthor: false,
            onReply: () {},
            onReport: () => reported++,
          ),
        ),
      ),
    );
    final button = find.widgetWithText(TextButton, 'Report');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(reported, 1);
  });

  testWidgets('no Report button when reporting is not offered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CommentTile(
            comment: Comment.fromMap('c1', 'p1', {
              'alias': 'Gentle Heron',
              'content': 'Same here.',
            }),
            isAuthor: false,
          ),
        ),
      ),
    );
    expect(find.text('Report'), findsNothing);
  });
}
