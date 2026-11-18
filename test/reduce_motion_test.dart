import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/user_profile.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/screens/help_screen.dart';
import 'package:women_community_support/presentation/screens/membership/membership_flow.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';
import 'package:women_community_support/presentation/widgets/empty_state.dart';
import 'package:women_community_support/presentation/widgets/feed_greeting.dart';
import 'package:women_community_support/presentation/widgets/floating_illustration.dart';

/// With "reduce motion" on, a screen must settle immediately: nothing keeps
/// asking for new frames (no floating character, no entrance, no loops).
Future<void> expectStill(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  expect(
    tester.binding.hasScheduledFrame,
    isFalse,
    reason: '${screen.runtimeType} is still animating with reduce motion on',
  );
}

void main() {
  testWidgets('onboarding is still', (tester) async {
    await expectStill(
      tester,
      OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
    );
  });

  testWidgets('sign in is still', (tester) async {
    await expectStill(tester, const LoginScreen());
  });

  testWidgets('women-only step is still', (tester) async {
    await expectStill(tester, const MembershipFlow(profile: UserProfile()));
  });

  testWidgets('birthday step is still', (tester) async {
    await expectStill(
      tester,
      const MembershipFlow(profile: UserProfile(isWoman: true)),
    );
  });

  testWidgets('empty state is still', (tester) async {
    await expectStill(
      tester,
      const Scaffold(
        body: EmptyState(title: 'No discussions yet', message: 'Start one.'),
      ),
    );
  });

  testWidgets('empty state with the heart cat is still', (tester) async {
    await expectStill(
      tester,
      const Scaffold(
        body: EmptyState(
          illustration: LoomaCats.heart,
          title: 'Nothing found',
          message: 'No discussions match.',
        ),
      ),
    );
  });

  testWidgets('get help is still', (tester) async {
    await expectStill(tester, const HelpScreen());
  });

  testWidgets('home greeting is still', (tester) async {
    await expectStill(tester, const Scaffold(body: FeedGreeting(posts: [])));
  });
}
