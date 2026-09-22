// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/presentation/screens/auth/login_screen.dart';

void main() {
  testWidgets('login screen shows the email/password sign-in form', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Verify that our counter starts at 0.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('sign up link switches the screen to account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pump();

    expect(find.text('Create Account'), findsNWidgets(2));
    expect(find.text('Already have an account? Sign In'), findsOneWidget);
  });
}
