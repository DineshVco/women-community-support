import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

/// She closed the Google window, pressed back or chose no account. A normal
/// outcome, not an error: the sign-in screen simply returns to normal.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// The sign-in calls the sign-in screen makes. Tests pass a fake.
class LoginAuth {
  const LoginAuth();

  /// Firebase web error codes that mean "she closed or cancelled it".
  static const Set<String> webCancelCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'user-cancelled',
  };

  /// Whether [error] (from Google or Firebase) is just a cancel.
  static bool isCancel(Object error) {
    if (error is SignInCancelled) return true;
    if (error is FirebaseAuthException) {
      return webCancelCodes.contains(error.code);
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      return code == 'sign_in_canceled' ||
          code == 'canceled' ||
          code == 'cancelled' ||
          code.contains('cancel');
    }
    return false;
  }

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
