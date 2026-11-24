import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;

/// She closed the Google window, pressed back or chose no account. A normal
/// outcome, not an error: the screen simply returns to normal.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Firebase web error codes that mean "she closed or cancelled it".
const Set<String> webSignInCancelCodes = {
  'popup-closed-by-user',
  'cancelled-popup-request',
  'user-cancelled',
};

/// Whether [error] (from Google or Firebase) is just a cancel.
bool isSignInCancel(Object error) {
  if (error is SignInCancelled) return true;
  if (error is FirebaseAuthException) {
    return webSignInCancelCodes.contains(error.code);
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
