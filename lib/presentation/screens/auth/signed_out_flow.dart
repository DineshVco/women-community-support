import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/onboarding_progress.dart';
import '../onboarding_screen.dart';
import 'login_screen.dart';

/// Onboarding first (only until it has been finished once on this phone),
/// then sign in / sign up. When sign-in succeeds, AuthGate replaces this
/// whole flow with the app.
class SignedOutFlow extends StatefulWidget {
  const SignedOutFlow({super.key});

  @override
  State<SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<SignedOutFlow> {
  /// Null while the saved answer loads (a plain page, so the introduction
  /// never flashes up for someone who has seen it).
  bool? _showLogin;
  bool _startInSignUp = false;

  @override
  void initState() {
    super.initState();
    OnboardingProgress.seen().then((seen) {
      if (mounted) setState(() => _showLogin ??= seen);
    });
  }

  void _openLogin({required bool signUp}) {
    OnboardingProgress.markSeen();
    setState(() {
      _showLogin = true;
      _startInSignUp = signUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showLogin = _showLogin;
    if (showLogin == null) {
      return ColoredBox(color: context.palette.background);
    }
    if (showLogin) {
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
