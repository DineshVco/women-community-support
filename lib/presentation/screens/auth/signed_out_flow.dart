import 'package:flutter/material.dart';

import '../onboarding_screen.dart';
import 'login_screen.dart';

/// Onboarding first, then sign in / sign up. When sign-in succeeds, AuthGate
/// replaces this whole flow with the app.
class SignedOutFlow extends StatefulWidget {
  const SignedOutFlow({super.key});

  @override
  State<SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<SignedOutFlow> {
  /// Onboarding is shown once per app launch. After signing out, people go
  /// straight to "Welcome back". (Remembering it across launches would need
  /// local storage, which would mean adding a package.)
  static bool _seenOnboarding = false;

  late bool _showLogin = _seenOnboarding;
  bool _startInSignUp = false;

  void _openLogin({required bool signUp}) {
    _seenOnboarding = true;
    setState(() {
      _showLogin = true;
      _startInSignUp = signUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return LoginScreen(
        // A new key makes the screen restart in the right mode.
        key: ValueKey(_startInSignUp),
        initialSignUp: _startInSignUp,
        onBack: () => setState(() => _showLogin = false),
      );
    }

    return OnboardingScreen(
      onGetStarted: () => _openLogin(signUp: true),
      onSignIn: () => _openLogin(signUp: false),
    );
  }
}
