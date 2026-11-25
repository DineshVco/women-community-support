import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/user_profile.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/membership/membership_flow.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';

class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _NoAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Repo extends PostRepository {
  _Repo() : super(firestore: _NoDb(), auth: _NoAuth());

  final saved = <String?>[];

  @override
  Future<void> setCallName(String? name) async => saved.add(name);
}

String _greeting(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('greeting'))).data!;

void main() {
  group('the greeting follows the clock without a restart', () {
    Future<void> pump(WidgetTester tester, DateTime Function() clock) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: FeedGreeting(name: 'Bee', clock: clock)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('when the hour changes (11:59 to 12:00)', (tester) async {
      var now = DateTime(2026, 11, 25, 11, 59, 30);
      await pump(tester, () => now);
      expect(_greeting(tester), 'Good morning, Bee');

      now = DateTime(2026, 11, 25, 12, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(_greeting(tester), 'Good afternoon, Bee');

      // And again at the next hour (17:59 to 18:00), after a long wait.
      now = DateTime(2026, 11, 25, 18, 0, 1);
      await tester.pump(const Duration(hours: 1));
      expect(_greeting(tester), 'Good evening, Bee');
    });

    testWidgets('when Looma comes back to the front', (tester) async {
      var now = DateTime(2026, 11, 25, 9);
      await pump(tester, () => now);
      expect(_greeting(tester), 'Good morning, Bee');

      // She leaves the app in the morning and comes back in the evening
      // (the phone slept, so no timer ran).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 11, 25, 19, 30);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_greeting(tester), 'Good evening, Bee');
    });

    testWidgets('no name: just "Good morning"', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: FeedGreeting(now: DateTime(2026, 11, 25, 8))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_greeting(tester), 'Good morning');
    });
  });

  group('"What should we call you?" after sign-up (email accounts)', () {
    Future<_Repo> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _Repo();
      await tester.pumpWidget(
        Provider<PostRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MembershipFlow(
              profile: UserProfile(isWoman: true),
              askName: true,
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return repo;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('short and honest; skipping saves nothing', (tester) async {
      final repo = await pump(tester);
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.textContaining('Only you see this name.'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 4'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(find.text('When’s your birthday?'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 3 of 4'), findsOneWidget);
      expect(repo.saved, isEmpty);
    });

    testWidgets('a name is saved; empty, too long or an email cannot be', (
      tester,
    ) async {
      final repo = await pump(tester);
      final field = find.byKey(const ValueKey('call-name'));
      LoomaButtonFinder.continueEnabled(tester, isFalse);

      await tester.enterText(field, 'bee@mail.com');
      await tester.pump();
      LoomaButtonFinder.continueEnabled(tester, isFalse);
      await tester.enterText(field, 'x' * 21);
      await tester.pump();
      LoomaButtonFinder.continueEnabled(tester, isFalse);

      await tester.enterText(field, '  Kak Ti ');
      await tester.pump();
      LoomaButtonFinder.continueEnabled(tester, isTrue);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(repo.saved, ['Kak Ti']);
      expect(find.text('When’s your birthday?'), findsOneWidget);
    });

    testWidgets('Google accounts (with a name) skip the step', (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MembershipFlow(profile: UserProfile(isWoman: true)),
        ),
      );
      await settle(tester);
      expect(find.text('What should we call you?'), findsNothing);
      expect(find.text('When’s your birthday?'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    });
  });
}

/// The step's "Continue" button is enabled or not.
class LoomaButtonFinder {
  static void continueEnabled(WidgetTester tester, Matcher matcher) {
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed != null, matcher);
  }
}
