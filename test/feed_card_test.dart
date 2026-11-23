import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/home_screen.dart';
import 'package:women_community_support/presentation/widgets/alias_avatar.dart';
import 'package:women_community_support/presentation/widgets/category_label.dart';
import 'package:women_community_support/presentation/widgets/looma_card.dart';
import 'package:women_community_support/presentation/widgets/post_card.dart';

class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _NoAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _FakeRepo extends PostRepository {
  _FakeRepo() : super(firestore: _NoDb(), auth: _NoAuth());

  @override
  Stream<bool> watchVoted(String postId) => Stream.value(false);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Post _post(String id, {String alias = 'Quiet Fox', bool poll = false}) => Post(
  id: id,
  alias: alias,
  categoryId: 'education',
  title: 'Scholarship tips?',
  content: 'Any advice?',
  timestamp: DateTime(2026, 11, 23, 9),
  meTooCount: 4,
  commentCount: 3,
  type: poll ? 'poll' : null,
  options: poll ? const ['Yes', 'No'] : const [],
  voteCounts: poll ? const [1, 2] : const [],
);

Widget _app(Widget child, {ThemeData? theme, bool reduceMotion = false}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: ListView(children: [child])),
      ),
    );

BoxDecoration _cardDecoration(WidgetTester tester, Finder within) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: within, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('category pills', () {
    test('soft colours: Health sage, Education sand, Career blush, '
        'Safety lavender', () {
      final p = AppPalette.light;
      final fills = {
        for (final id in [
          'health_wellness',
          'education',
          'career_development',
          'personal_safety',
        ])
          id: p.categoryFill(id),
      };
      expect(fills.values.toSet(), hasLength(4)); // all different
      // Sage is greenest, blush is reddest, lavender is bluest.
      Color f(String id) => fills[id]!;
      expect(f('health_wellness').g, greaterThan(f('health_wellness').r));
      expect(f('career_development').r, greaterThan(f('career_development').b));
      expect(f('personal_safety').b, greaterThan(f('personal_safety').g));
    });

    for (final (name, p) in [
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name: pill text passes AA on every pill', () {
        for (final id in [
          'health_wellness',
          'education',
          'career_development',
          'personal_safety',
          'ask_looma',
        ]) {
          expect(
            _contrast(p.text, p.categoryFill(id)),
            greaterThanOrEqualTo(4.5),
            reason: id,
          );
        }
      });
    }

    testWidgets('a post card shows its category as a pill', (tester) async {
      await tester.pumpWidget(_app(PostCard(post: _post('p1'))));
      expect(find.byType(CategoryLabel), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
    });
  });

  group('cards', () {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      testWidgets('$name: radius 20, 1 px warm border, soft shadow in light', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(PostCard(post: _post('p1')), theme: theme),
        );
        final box = _cardDecoration(tester, find.byType(LoomaCard));
        expect(box.borderRadius, BorderRadius.circular(20));
        expect((box.border! as Border).top.width, 1);
        if (theme.brightness == Brightness.light) {
          expect(box.boxShadow, hasLength(2)); // layered
        } else {
          expect(box.boxShadow ?? const [], isEmpty); // no glow on black
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cards are 12 px apart', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                PostCard(post: _post('p1')),
                PostCard(post: _post('p2')),
              ],
            ),
          ),
        ),
      );
      final cards = find.byType(LoomaCard);
      final first = tester.getRect(cards.at(0));
      final second = tester.getRect(cards.at(1));
      expect(second.top - first.bottom, LoomaCard.gap);
    });

    testWidgets('poll cards get the same card', (tester) async {
      await tester.pumpWidget(
        Provider<PostRepository>.value(
          value: _FakeRepo(),
          child: _app(PostCard(post: _post('p1', poll: true))),
        ),
      );
      await tester.pump();
      expect(find.text('Yes'), findsOneWidget); // answerable on the card
      expect(find.byType(LoomaCard), findsOneWidget);
    });

    testWidgets('icon actions: me too and replies, read out in words', (
      tester,
    ) async {
      await tester.pumpWidget(_app(PostCard(post: _post('p1'))));
      // In a list the card is read as one item, counts in words.
      expect(find.bySemanticsLabel(RegExp('4 me too')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('3 replies')), findsOneWidget);
    });

    testWidgets('a tap: light haptic and 98% press scale', (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      var taps = 0;
      await tester.pumpWidget(
        _app(PostCard(post: _post('p1'), onTap: () => taps++)),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.text('Scholarship tips?')),
      );
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byType(LoomaCard),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, 0.98);
      await finger.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('Reduce motion: no press scale', (tester) async {
      await tester.pumpWidget(
        _app(PostCard(post: _post('p1'), onTap: () {}), reduceMotion: true),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.text('Scholarship tips?')),
      );
      await tester.pump();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1);
      await finger.up();
    });
  });

  group('avatars', () {
    test('the same alias always gets the same drawing', () {
      expect(
        AliasAvatar.indexFor('Quiet Fox'),
        AliasAvatar.indexFor('Quiet Fox'),
      );
      final drawings = {
        for (final a in ['Quiet Fox', 'Gentle Heron', 'Brave Lark', 'Soft Owl'])
          AliasAvatar.drawings[AliasAvatar.indexFor(a) %
              AliasAvatar.drawings.length],
      };
      expect(drawings.length, greaterThan(1)); // not all the same
    });

    testWidgets('next to the alias on every post', (tester) async {
      await tester.pumpWidget(_app(PostCard(post: _post('p1'))));
      expect(find.byType(AliasAvatar), findsOneWidget);
    });
  });

  testWidgets('"Write a post" is a 44 px pill and keeps room below cards', (
    tester,
  ) async {
    await tester.pumpWidget(_app(WritePill(extended: true, onPressed: () {})));
    expect(tester.getSize(find.byType(WritePill)).height, WritePill.height);
    expect(WritePill.height, 44);
    // The room under the last card covers the pill and its 16 px margin.
    expect(WritePill.room, greaterThanOrEqualTo(WritePill.height + 16));
  });
}
