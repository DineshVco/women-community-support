import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../data/auth/sign_in_cancel.dart';

export '../../../data/auth/sign_in_cancel.dart' show SignInCancelled;

/// The sign-in calls the sign-in screen makes. Tests pass a fake.
class LoginAuth {
  const LoginAuth();

  /// Whether [error] (from Google or Firebase) is just a cancel.
  static bool isCancel(Object error) => isSignInCancel(error);

  bool get signedIn => FirebaseAuth.instance.currentUser != null;

  Future<void> signInWithEmail(String email, String password) => FirebaseAuth
      .instance
      .signInWithEmailAndPassword(email: email, password: password);

  Future<void> createAccount(String email, String password) => FirebaseAuth
      .instance
      .createUserWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  /// Google sign-in. Throws [SignInCancelled] when she cancels.
  Future<void> signInWithGoogle() async {
    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
        return;
      }
      final googleUser = await GoogleSignIn().signIn();
      // Closed the Google window, pressed back, or chose no account.
      if (googleUser == null) throw const SignInCancelled();
      final googleAuth = await googleUser.authentication;
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
    } catch (error) {
      if (isCancel(error)) throw const SignInCancelled();
      rethrow;
    }
  }
}
