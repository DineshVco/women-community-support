import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'auth/signed_out_flow.dart';

/// Decides what to show: the app when someone is signed in (including guests),
/// otherwise onboarding / sign in. Reacts instantly to sign in and sign out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const SignedOutFlow();
        }

        return const AppShell();
      },
    );
  }
}
