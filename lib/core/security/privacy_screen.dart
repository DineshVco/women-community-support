import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hides Looma from the "recent apps" preview.
///
/// Android: the window's secure flag (FLAG_SECURE), set in MainActivity.
/// This also blocks screenshots and screen recording while it is on.
/// iOS and web: there is no such flag; AppLockGate covers the app with a
/// blank screen whenever it is not in front instead.
class PrivacyScreen {
  PrivacyScreen._();

  static const MethodChannel _channel = MethodChannel('looma/privacy');

  static bool get supportedNatively =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> setSecure(bool secure) async {
    if (!supportedNatively) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Tests and older builds: nothing to do.
    } on PlatformException {
      // Never let this break the app.
    }
  }
}
