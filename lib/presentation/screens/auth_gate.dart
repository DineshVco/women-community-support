import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/content_width.dart';
import '../widgets/looma_loader.dart';
import '../widgets/empty_state.dart';
import '../widgets/looma_button.dart';
import 'app_shell.dart';
import 'auth/sign_in_hold.dart';
import 'auth/signed_out_flow.dart';
import 'membership/membership_flow.dart';

/// Decides what to show:
///  * signed out → onboarding / sign in
///  * an old guest (anonymous) session → sign it out, then onboarding / sign in
///  * signed in, sign-up steps not finished → women-only + birthday steps
///  * signed in and finished → the app
/// Reacts instantly to sign in, sign out and saved answers.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // Always wrapped the same way, so the sign-in screen keeps its state
      // while it shows the success tick.
      builder:
          (context, snapshot) => ValueListenableBuilder<bool>(
            valueListenable: SignInHold.active,
            builder: (context, holding, _) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Loading();
              }

              final user = snapshot.data;
              // `holding`: just signed in, the button is showing its tick.
              if (user == null || holding) return const SignedOutFlow();

              // Looma has no guest accounts any more, and the database refuses
              // them. A guest session saved on the phone from an older version
              // is signed out; authStateChanges then shows onboarding / sign in.
              if (user.isAnonymous) {
                return GuestSessionCleanup(
                  key: ValueKey('guest-${user.uid}'),
                  onSignOut: context.read<PostRepository>().signOut,
                );
              }

              // A new key per account restarts the profile check.
              return _ProfileGate(key: ValueKey(user.uid));
            },
          ),
    );
  }
}

/// Shown for a moment while an old guest session is signed out.
/// Calls [onSignOut] exactly once, however often it is rebuilt.
class GuestSessionCleanup extends StatefulWidget {
  const GuestSessionCleanup({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<GuestSessionCleanup> createState() => _GuestSessionCleanupState();
}

class _GuestSessionCleanupState extends State<GuestSessionCleanup> {
  @override
  void initState() {
    super.initState();
    // Errors are ignored on purpose: even if signing out fails, the screen
    // offers nothing else, and the next launch tries again.
    widget.onSignOut().catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => const _Loading();
}

/// "Could not load your account" with Try again AND Sign out, so nobody is
/// ever stuck on this screen.
class AccountLoadError extends StatelessWidget {
  const AccountLoadError({
    super.key,
    required this.onRetry,
    required this.onSignOut,
  });

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ContentWidth(
            maxWidth: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmptyState(
                    title: 'Could not load your account',
                    message:
                        'Check your internet connection and try again. '
                        'If it keeps happening, sign out and sign in again.',
                    actionLabel: 'Try again',
                    onAction: onRetry,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: LoomaButton.outline(
                      label: 'Sign out',
                      onPressed: onSignOut,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    // The cat watching the yarn roll (still with Reduce motion).
    return const LoomaLoadingScreen();
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Stream<UserProfile> _profile = _watch();

  Stream<UserProfile> _watch() => context.read<PostRepository>().watchProfile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile>(
      stream: _profile,
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.hasError) {
          child = AccountLoadError(
            key: const ValueKey('error'),
            onRetry: () => setState(() => _profile = _watch()),
            onSignOut: () => context.read<PostRepository>().signOut(),
          );
        } else if (!snapshot.hasData) {
          child = const _Loading(key: ValueKey('loading'));
        } else if (snapshot.data!.isComplete) {
          child = const AppShell(key: ValueKey('app'));
        } else {
          child = MembershipFlow(
            key: const ValueKey('steps'),
            profile: snapshot.data!,
          );
        }

        return AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.medium),
          child: child,
        );
      },
    );
  }
}
