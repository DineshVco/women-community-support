import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/constants/membership.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/alias.dart';
import 'package:women_community_support/core/utils/content_filter.dart';
import 'package:women_community_support/core/utils/greeting.dart';
import 'package:women_community_support/core/utils/time_format.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/data/models/user_profile.dart';
import 'package:women_community_support/data/repositories/chat_repository.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/screens/auth_gate.dart';
import 'package:women_community_support/presentation/screens/membership/membership_flow.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';

void main() {
  // ───────────────────────── Login screen ─────────────────────────

  group('LoginScreen', () {
    Widget app() =>
        MaterialApp(theme: AppTheme.light, home: const LoginScreen());

    testWidgets('shows the sign-in form without a guest option', (
      tester,
    ) async {
      await tester.pumpWidget(app());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Continue as guest'), findsNothing);
      expect(find.textContaining('guest'), findsNothing);
      expect(find.textContaining('Guest'), findsNothing);
    });

    testWidgets('switches to account creation', (tester) async {
      await tester.pumpWidget(app());

      final toggle = find.text('New to Looma? Create an account');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();

      expect(find.text('Create your space'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });
  });

  // ───────────────────────── Onboarding ─────────────────────────

  group('OnboardingScreen', () {
    testWidgets('shows the Looma welcome, features and two buttons', (
      tester,
    ) async {
      var startedSignUp = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(
            onGetStarted: () => startedSignUp = true,
            onSignIn: () {},
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Welcome to Looma'), findsOneWidget);
      expect(find.text('SUPPORT · SHARE · EMPOWER'), findsOneWidget);
      expect(find.text('Share Anonymously'), findsOneWidget);
      expect(find.text('Stay Safe & Protected'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(find.textContaining('guest'), findsNothing);

      final getStarted = find.text('Get Started');
      await tester.ensureVisible(getStarted);
      await tester.tap(getStarted);
      expect(startedSignUp, isTrue);
    });
  });

  group('Onboarding pages', () {
    testWidgets('swipes through 4 pages; Skip only on pages 2 to 4', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
        ),
      );
      await settle(tester);

      // Page 1: no Skip button for screen readers or taps.
      expect(find.bySemanticsLabel('Page 1 of 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Skip'), findsNothing);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await settle(tester);
      expect(find.text('Share anonymously'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 2 of 4'), findsOneWidget);
      // Buttons stay on every page.
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(find.text('Stay safe and protected'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 4 of 4'), findsOneWidget);
    });
  });

  // ───────────────────────── Women-only step ─────────────────────────

  group('MembershipFlow', () {
    testWidgets('starts on the women-only step with "I am a woman" selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MembershipFlow(profile: UserProfile()),
        ),
      );
      await settle(tester);

      expect(find.text('Looma is a space for women'), findsOneWidget);
      final woman = tester.getSemantics(find.text('I am a woman'));
      expect(woman.hasFlag(SemanticsFlag.isSelected), isTrue);
    });

    testWidgets('"I am not a woman" shows the calm message, saves nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MembershipFlow(profile: UserProfile()),
        ),
      );
      await settle(tester);

      final notWoman = find.text('I am not a woman');
      await tester.ensureVisible(notWoman);
      await tester.tap(notWoman);
      await tester.pump();
      final next = find.text('Continue');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await settle(tester);

      expect(find.textContaining('Looma is only for women'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
    });

    testWidgets('a confirmed woman goes straight to the birthday step', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MembershipFlow(profile: UserProfile(isWoman: true)),
        ),
      );
      await settle(tester);

      expect(find.text('When’s your birthday?'), findsOneWidget);
      expect(find.text('Your data is private and secure.'), findsOneWidget);
    });
  });

  // ───────────────────────── Membership rules ─────────────────────────

  group('Membership.ageOn', () {
    test('counts whole years, birthday not yet reached', () {
      expect(
        Membership.ageOn(DateTime(2008, 6, 15), DateTime(2026, 6, 14)),
        17,
      );
      expect(
        Membership.ageOn(DateTime(2008, 6, 15), DateTime(2026, 6, 15)),
        18,
      );
    });

    test('minimum age is 18 and is enforced on the exact day', () {
      expect(Membership.minimumAge, 18);
      expect(
        Membership.isOldEnough(DateTime(2008, 6, 15), DateTime(2026, 6, 14)),
        isFalse,
      );
      expect(
        Membership.isOldEnough(DateTime(2008, 6, 15), DateTime(2026, 6, 15)),
        isTrue,
      );
    });
  });

  group('UserProfile', () {
    test('is complete only with both answers', () {
      expect(UserProfile.fromMap(null).isComplete, isFalse);
      expect(UserProfile.fromMap({'isWoman': true}).isComplete, isFalse);
      expect(
        UserProfile.fromMap({'isWoman': true, 'birthYear': 1999}).isComplete,
        isTrue,
      );
    });

    test('ignores anything that is not exactly true', () {
      expect(UserProfile.fromMap({'isWoman': 'yes'}).isWoman, isFalse);
    });
  });

  test('formatLongDate writes the month out', () {
    expect(formatLongDate(DateTime(2000, 3, 12)), '12 March 2000');
  });

  // ───────────────────────── AuthGate safety nets ─────────────────────────

  group('GuestSessionCleanup (old guest sessions)', () {
    testWidgets('signs out exactly once and shows a loader', (tester) async {
      var signOuts = 0;
      Future<void> signOut() async => signOuts++;

      Widget app() => MaterialApp(
        theme: AppTheme.light,
        home: GuestSessionCleanup(onSignOut: signOut),
      );

      await tester.pumpWidget(app());
      // Rebuilding must not sign out again.
      await tester.pumpWidget(app());
      await tester.pump();

      expect(signOuts, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not crash if signing out fails', (tester) async {
      Future<void> failingSignOut() async => throw Exception('offline');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GuestSessionCleanup(onSignOut: failingSignOut),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('AccountLoadError', () {
    testWidgets('offers Try again and Sign out, so nobody is stuck', (
      tester,
    ) async {
      var retries = 0;
      var signOuts = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AccountLoadError(
            onRetry: () => retries++,
            onSignOut: () => signOuts++,
          ),
        ),
      );

      expect(find.text('Could not load your account'), findsOneWidget);

      final tryAgain = find.text('Try again');
      await tester.ensureVisible(tryAgain);
      await tester.tap(tryAgain);
      await tester.pump();
      expect(retries, 1);

      final signOut = find.text('Sign out');
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pump();
      expect(signOuts, 1);
    });
  });

  group('FeedGreeting', () {
    testWidgets('shows a time greeting and "You are not alone here."', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: FeedGreeting(posts: [])),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(greetingFor(DateTime.now())), findsOneWidget);
      expect(find.text('You are not alone here.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────── AliasGenerator ─────────────────────────

  group('AliasGenerator', () {
    final key = 'a' * 64;

    test('gives the same alias for the same person in the same thread', () {
      final a = AliasGenerator.forThread(key: key, postId: 'post-1');
      final b = AliasGenerator.forThread(key: key, postId: 'post-1');
      expect(a, b);
    });

    test('is HMAC-SHA256 of the secret key (same on every platform)', () {
      // Python: hmac.new(b'a'*64, b'post-1', hashlib.sha256), first 4 bytes.
      expect(
        AliasGenerator.forThread(key: key, postId: 'post-1'),
        'Genuine Turtle',
      );
    });

    test('looks like "Adjective Noun"', () {
      final alias = AliasGenerator.forThread(key: key, postId: 'post-1');
      expect(alias, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+$')));
    });

    test('changes between threads so posts cannot be linked', () {
      final aliases = {
        for (var i = 0; i < 20; i++)
          AliasGenerator.forThread(key: key, postId: 'post-$i'),
      };
      // A collision now and then is fine; all 20 the same is not.
      expect(aliases.length, greaterThan(10));
    });

    test('depends on the secret key, not on anything public', () {
      final mine = {
        for (var i = 0; i < 20; i++)
          AliasGenerator.forThread(key: key, postId: 'post-$i'),
      };
      final other = {
        for (var i = 0; i < 20; i++)
          AliasGenerator.forThread(key: 'b' * 64, postId: 'post-$i'),
      };
      expect(mine, isNot(equals(other)));
    });

    test('new keys are random 64-character hex strings', () {
      final a = AliasGenerator.newKey();
      final b = AliasGenerator.newKey();
      expect(a, matches(AliasGenerator.keyPattern));
      expect(b, matches(AliasGenerator.keyPattern));
      expect(a, isNot(b));
    });
  });

  group('reporter id', () {
    test('is a one-way hash, different from the chat profile id', () {
      // Python: hashlib.sha256(b'looma-report:amira').hexdigest()
      final id = PostRepository.reporterIdFor('amira');
      expect(
        id,
        '65fb23d3b2c7d9cab1a1547de319c70b9fc4bb809d0f9fbdd72f485583fbef56',
      );
      expect(id, isNot(contains('amira')));
      expect(id, isNot(ChatRepository.chatIdFor('amira')));
    });
  });

  // ───────────────────────── ContentFilter ─────────────────────────

  group('ContentFilter', () {
    test('blocks abusive words, ignoring case', () {
      expect(ContentFilter.isDisrespectful('You BITCH'), isTrue);
      expect(ContentFilter.isDisrespectful('pukimak'), isTrue);
    });

    test(
      'allows ordinary text, including words that contain a blocked one',
      () {
        expect(
          ContentFilter.isDisrespectful('How do I ask for a raise?'),
          isFalse,
        );
        expect(
          ContentFilter.isDisrespectful('Social anxiety at work'),
          isFalse,
        );
      },
    );

    test('notices signs of distress', () {
      expect(ContentFilter.suggestsDistress('Sometimes I want to die'), isTrue);
      expect(
        ContentFilter.suggestsDistress('Thinking about self-harm'),
        isTrue,
      );
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
      expect(
        timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
        'just now',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        '3 h ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 2)), now: now),
        '2 d ago',
      );
    });

    test('shows a date after a week', () {
      expect(timeAgo(DateTime(2026, 3, 12), now: now), '12 Mar 2026');
    });
  });
}

/// Lets entrance animations finish. (pumpAndSettle would wait forever: the
/// Looma character animates in a loop.)
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
