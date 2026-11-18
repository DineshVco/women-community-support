import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/alias.dart';
import 'package:women_community_support/core/utils/content_filter.dart';
import 'package:women_community_support/core/utils/time_format.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';

void main() {
  // ───────────────────────── Login screen ─────────────────────────

  group('LoginScreen', () {
    Widget app() => MaterialApp(theme: AppTheme.light, home: const LoginScreen());

    testWidgets('shows the sign-in form and the guest option', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue as guest'), findsOneWidget);
    });

    testWidgets('switches to account creation', (tester) async {
      await tester.pumpWidget(app());

      final toggle = find.text('New here? Create an account');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });
  });

  // ───────────────────────── AliasGenerator ─────────────────────────

  group('AliasGenerator', () {
    test('gives the same alias for the same person in the same thread', () {
      final a = AliasGenerator.forThread(uid: 'user-1', postId: 'post-1');
      final b = AliasGenerator.forThread(uid: 'user-1', postId: 'post-1');
      expect(a, b);
    });

    test('looks like "Adjective Noun"', () {
      final alias = AliasGenerator.forThread(uid: 'user-1', postId: 'post-1');
      expect(alias, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+$')));
    });

    test('changes between threads so posts cannot be linked', () {
      final aliases = {
        for (var i = 0; i < 20; i++)
          AliasGenerator.forThread(uid: 'user-1', postId: 'post-$i'),
      };
      // A collision now and then is fine; all 20 the same is not.
      expect(aliases.length, greaterThan(10));
    });
  });

  // ───────────────────────── ContentFilter ─────────────────────────

  group('ContentFilter', () {
    test('blocks abusive words, ignoring case', () {
      expect(ContentFilter.isDisrespectful('You BITCH'), isTrue);
      expect(ContentFilter.isDisrespectful('pukimak'), isTrue);
    });

    test('allows ordinary text, including words that contain a blocked one',
        () {
      expect(ContentFilter.isDisrespectful('How do I ask for a raise?'),
          isFalse);
      expect(ContentFilter.isDisrespectful('Social anxiety at work'), isFalse);
    });

    test('notices signs of distress', () {
      expect(ContentFilter.suggestsDistress('Sometimes I want to die'), isTrue);
      expect(ContentFilter.suggestsDistress('Thinking about self-harm'),
          isTrue);
      expect(ContentFilter.suggestsDistress('Tired after exams'), isFalse);
    });
  });

  // ───────────────────────── Post.fromMap ─────────────────────────

  group('Post.fromMap', () {
    test('reads every field', () {
      final time = DateTime(2026, 3, 12, 9, 30);
      final post = Post.fromMap('p1', {
        'alias': 'Quiet Fox',
        'categoryId': 'education',
        'title': 'Scholarships',
        'content': 'Any tips?',
        'timestamp': Timestamp.fromDate(time),
        'flagCount': 1,
        'meTooCount': 4,
        'commentCount': 2,
        'status': 'hidden',
      });

      expect(post.id, 'p1');
      expect(post.alias, 'Quiet Fox');
      expect(post.categoryId, 'education');
      expect(post.title, 'Scholarships');
      expect(post.content, 'Any tips?');
      expect(post.timestamp, time);
      expect(post.flagCount, 1);
      expect(post.meTooCount, 4);
      expect(post.commentCount, 2);
      expect(post.isVisible, isFalse);
    });

    test('uses safe defaults for missing fields', () {
      final post = Post.fromMap('p2', {});

      expect(post.alias, 'Anonymous');
      expect(post.title, '');
      expect(post.meTooCount, 0);
      expect(post.commentCount, 0);
      expect(post.status, 'visible');
      expect(post.isVisible, isTrue);
    });

    test('falls back to the old displayName field', () {
      final post = Post.fromMap('p3', {'displayName': 'Old Name'});
      expect(post.alias, 'Old Name');
    });
  });

  // ───────────────────────── timeAgo ─────────────────────────

  group('timeAgo', () {
    final now = DateTime(2026, 3, 20, 12);

    test('formats recent times', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
          'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
          '5 min ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now),
          '3 h ago');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now: now),
          '2 d ago');
    });

    test('shows a date after a week', () {
      expect(timeAgo(DateTime(2026, 3, 12), now: now), '12 Mar 2026');
    });
  });
}
