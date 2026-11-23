import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/onboarding_progress.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/screens/auth/signed_out_flow.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (context, child) => MediaQuery(
        // Still pictures: the onboarding cat floats otherwise.
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
  home: home,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch: the introduction; finishing it is remembered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const SignedOutFlow()));
    await _settle(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('I already have an account'));
    await _settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await OnboardingProgress.seen(), isTrue);

    // Next launch (a fresh flow): straight to sign in.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(const SignedOutFlow()));
    await _settle(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('already seen on this phone: no introduction', (tester) async {
    SharedPreferences.setMockInitialValues({OnboardingProgress.key: true});
    await tester.pumpWidget(_app(const SignedOutFlow()));
    await _settle(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('"View introduction": only a Done button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var done = 0;
    await tester.pumpWidget(
      _app(
        OnboardingScreen(
          viewOnly: true,
          onGetStarted: () => done++,
          onSignIn: () {},
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    expect(find.text('I already have an account'), findsNothing);
    await tester.tap(find.text('Done'));
    expect(done, 1);
  });
}
