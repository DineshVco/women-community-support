import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/auth/login_auth.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/screens/auth/sign_in_hold.dart';

/// A pretend sign-in: each call waits for the test to finish it.
class _FakeAuth extends LoginAuth {
  final calls = <String>[];
  Completer<void> pending = Completer<void>();

  @override
  bool get signedIn => false;

  Future<void> _wait(String name) {
    calls.add(name);
    pending = Completer<void>();
    return pending.future;
  }

  @override
  Future<void> signInWithGoogle() => _wait('google');

  @override
  Future<void> signInWithEmail(String email, String password) => _wait('email');

  @override
  Future<void> createAccount(String email, String password) => _wait('create');

  @override
  Future<void> sendPasswordReset(String email) => _wait('reset');
}

final _google = find.text('Continue with Google');
final _continue = find.text('Continue');

Future<_FakeAuth> _pump(WidgetTester tester, {bool signUp = false}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _FakeAuth();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
      home: LoginScreen(auth: auth, initialSignUp: signUp),
    ),
  );
  await tester.pump();
  return auth;
}

/// The spinner on a button is showing.
bool _loading(WidgetTester tester) =>
    find.byKey(const ValueKey('loading')).evaluate().isNotEmpty;

/// The email field can be typed in (the screen is usable again).
bool _usable(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).enabled ?? true;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => SignInHold.active.value = false);

  group('Google sign-in: cancel is a normal outcome', () {
    for (final (name, cancel) in <(String, Object)>[
      ('closed the window / no account (null)', const SignInCancelled()),
      (
        'Android "sign_in_canceled"',
        PlatformException(code: 'sign_in_canceled'),
      ),
      ('"canceled"', PlatformException(code: 'canceled')),
      (
        'web popup-closed-by-user',
        FirebaseAuthException(code: 'popup-closed-by-user'),
      ),
      (
        'web cancelled-popup-request',
        FirebaseAuthException(code: 'cancelled-popup-request'),
      ),
      ('web user-cancelled', FirebaseAuthException(code: 'user-cancelled')),
    ]) {
      testWidgets('$name: back to normal, no message', (tester) async {
        final auth = await _pump(tester, signUp: true);
        expect(find.text('Create your space'), findsOneWidget);
        await tester.tap(_google);
        await tester.pump();
        expect(_loading(tester), isTrue);
        expect(_usable(tester), isFalse);
        expect(SignInHold.active.value, isTrue);

        auth.pending.completeError(cancel);
        await _settle(tester);

        expect(_loading(tester), isFalse);
        expect(_usable(tester), isTrue);
        expect(SignInHold.active.value, isFalse);
        // No message at all.
        expect(find.textContaining('try again'), findsNothing);
        expect(find.textContaining('closed'), findsNothing);
        // And she can tap again.
        await tester.tap(_google);
        await tester.pump();
        expect(auth.calls, ['google', 'google']);
        auth.pending.completeError(const SignInCancelled());
        await _settle(tester);
      });
    }

    test('what counts as a cancel', () {
      expect(LoginAuth.isCancel(const SignInCancelled()), isTrue);
      expect(
        LoginAuth.isCancel(PlatformException(code: 'sign_in_canceled')),
        isTrue,
      );
      expect(
        LoginAuth.isCancel(FirebaseAuthException(code: 'user-cancelled')),
        isTrue,
      );
      expect(
        LoginAuth.isCancel(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        isFalse,
      );
      expect(
        LoginAuth.isCancel(PlatformException(code: 'sign_in_failed')),
        isFalse,
      );
      expect(LoginAuth.isCancel(Exception('boom')), isFalse);
    });
  });

  testWidgets('an error shows a message and resets', (tester) async {
    final auth = await _pump(tester);
    await tester.tap(_google);
    await tester.pump();
    auth.pending.completeError(
      FirebaseAuthException(code: 'network-request-failed'),
    );
    await _settle(tester);
    expect(_loading(tester), isFalse);
    expect(_usable(tester), isTrue);
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(SignInHold.active.value, isFalse);
  });

  testWidgets('an unknown error: a friendly message, and resets', (
    tester,
  ) async {
    final auth = await _pump(tester);
    await tester.tap(_google);
    await tester.pump();
    auth.pending.completeError(PlatformException(code: 'sign_in_failed'));
    await _settle(tester);
    expect(_loading(tester), isFalse);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('no answer for 60 seconds: resets with a short message', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(_google);
    await tester.pump();
    await tester.pump(const Duration(seconds: 59));
    expect(_loading(tester), isTrue); // still waiting at 59 s
    await tester.pump(const Duration(seconds: 2));
    await _settle(tester);
    expect(_loading(tester), isFalse);
    expect(_usable(tester), isTrue);
    expect(find.text(LoginScreen.timeoutMessage), findsOneWidget);
    expect(SignInHold.active.value, isFalse);
  });

  testWidgets('a second tap while signing in is ignored', (tester) async {
    final auth = await _pump(tester);
    await tester.tap(_google);
    await tester.tap(_google, warnIfMissed: false); // same frame
    await tester.pump();
    await tester.tap(_google, warnIfMissed: false); // while loading
    await tester.pump();
    expect(auth.calls, ['google']);
    auth.pending.completeError(const SignInCancelled());
    await _settle(tester);
  });

  group('email sign-in has the same safety', () {
    Future<void> fillIn(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'bee@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'longpassword');
    }

    testWidgets('an error resets; a double tap is ignored', (tester) async {
      final auth = await _pump(tester);
      await fillIn(tester);
      await tester.tap(_continue);
      await tester.tap(_continue, warnIfMissed: false);
      await tester.pump();
      expect(auth.calls, ['email']);
      auth.pending.completeError(
        FirebaseAuthException(code: 'invalid-credential'),
      );
      await _settle(tester);
      expect(_loading(tester), isFalse);
      expect(
        find.text('The email address or password is incorrect.'),
        findsOneWidget,
      );
    });

    testWidgets('no answer for 60 seconds: resets', (tester) async {
      await _pump(tester, signUp: true);
      await fillIn(tester);
      await tester.tap(_continue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 61));
      await _settle(tester);
      expect(_loading(tester), isFalse);
      expect(find.text(LoginScreen.timeoutMessage), findsOneWidget);
    });

    testWidgets('Forgot password: resets after it finishes', (tester) async {
      final auth = await _pump(tester);
      await tester.enterText(find.byType(TextField).at(0), 'bee@example.com');
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      expect(auth.calls, ['reset']);
      expect(_usable(tester), isFalse);
      auth.pending.complete();
      await _settle(tester);
      expect(_usable(tester), isTrue);
      expect(find.textContaining('a reset link is on its way'), findsOneWidget);
    });
  });
}
