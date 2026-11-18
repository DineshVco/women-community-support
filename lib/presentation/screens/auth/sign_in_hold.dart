import 'package:flutter/foundation.dart';

/// Lets the sign-in screen stay visible for a moment after a successful
/// sign-in, so the button can show a tick before the app opens.
///
/// AuthGate keeps showing the signed-out screens while [active] is true.
/// The sign-in screen always sets it back to false (in a `finally`), so
/// nobody can get stuck.
class SignInHold {
  SignInHold._();

  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// How long the tick shows before the app opens.
  static const Duration tickDuration = Duration(milliseconds: 400);
}
