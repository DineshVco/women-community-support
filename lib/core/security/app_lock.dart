import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'pin_hasher.dart';
import 'privacy_screen.dart';
import 'secure_store.dart';

/// How soon Looma locks after going to the background.
enum LockAfter {
  immediately(Duration.zero, 'Immediately'),
  seconds30(Duration(seconds: 30), '30 seconds'),
  minute1(Duration(minutes: 1), '1 minute');

  const LockAfter(this.duration, this.label);

  final Duration duration;
  final String label;
}

enum PinResult { ok, wrong, wait }

/// The optional App lock: a 6-digit PIN (only a salted hash is stored, in
/// secure storage), optional fingerprint / Face unlock, a growing wait after
/// wrong PINs, and locking when Looma goes to the background.
///
/// Nothing here ever leaves the phone.
class AppLock extends ChangeNotifier {
  AppLock(
    this._store, {
    LocalAuthentication? auth,
    DateTime Function()? clock,
    Future<void> Function(bool secure)? setSecure,
    this.hashInBackground = true,
  }) : _auth = auth ?? LocalAuthentication(),
       _clock = clock ?? DateTime.now,
       _setSecure = setSecure ?? PrivacyScreen.setSecure;

  final SecureStore _store;
  final LocalAuthentication _auth;
  final DateTime Function() _clock;

  /// Hides the app preview (Android secure flag). Tests pass a no-op.
  final Future<void> Function(bool secure) _setSecure;

  /// Hash on a background isolate so the keypad never stutters. Tests turn
  /// it off.
  final bool hashInBackground;

  static const String pinKey = 'looma.lock.pinHash';
  static const String wrongKey = 'looma.lock.wrongTries';
  static const String untilKey = 'looma.lock.waitUntil';
  static const String biometricsKey = 'looma.lock.biometrics';
  static const String afterKey = 'looma.lock.after';
  static const String hidePreviewKey = 'looma.lock.hidePreview';

  String? _pinHash;
  bool _locked = false;
  bool _biometrics = false;
  bool _hidePreview = false;
  LockAfter _lockAfter = LockAfter.immediately;
  int _wrongTries = 0;
  DateTime? _waitUntil;
  DateTime? _backgroundedAt;
  bool _disguiseActive = false;

  /// The fingerprint / Face prompt is open. It can briefly send the app to
  /// the background, which must not count as "leaving".
  bool _authenticating = false;

  bool get enabled => _pinHash != null;
  bool get locked => enabled && _locked;
  bool get biometrics => _biometrics;
  bool get hidePreview => enabled && _hidePreview;
  LockAfter get lockAfter => _lockAfter;
  int get wrongTries => _wrongTries;

  /// A Quick exit disguise is on screen. The lock screen never shows on top
  /// of it (that would reveal Looma); it shows once she leaves the disguise.
  bool get disguiseActive => _disguiseActive;

  /// Time left before another PIN can be tried.
  Duration get waitLeft {
    final until = _waitUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> load() async {
    try {
      _pinHash = await _store.read(pinKey);
      _wrongTries = int.tryParse(await _store.read(wrongKey) ?? '') ?? 0;
      final until = int.tryParse(await _store.read(untilKey) ?? '');
      _waitUntil =
          until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
      _biometrics = await _store.read(biometricsKey) == 'true';
      _hidePreview = await _store.read(hidePreviewKey) != 'false';
    } catch (_) {
      // Unreadable secure storage: behave as if no lock was set.
    }
    _lockAfter = await _readLockAfter();
    // A fresh start counts as "away": lock straight away.
    _locked = enabled;
    await _applyPrivacy();
    notifyListeners();
  }

  Future<LockAfter> _readLockAfter() async {
    try {
      final name = await _store.read(afterKey);
      return LockAfter.values.firstWhere(
        (a) => a.name == name,
        orElse: () => LockAfter.immediately,
      );
    } catch (_) {
      return LockAfter.immediately;
    }
  }

  // ───────────── PIN ─────────────

  Future<String> _hash(String pin) =>
      hashInBackground
          ? compute(PinHasher.hash, pin)
          : Future.value(PinHasher.hash(pin));

  Future<bool> _verify(String pin, String stored) =>
      hashInBackground
          ? compute(_verifyArgs, [pin, stored])
          : Future.value(PinHasher.verify(pin, stored));

  static bool _verifyArgs(List<String> args) =>
      PinHasher.verify(args[0], args[1]);

  /// Turns App lock on (or changes the PIN). Hiding the app preview is on
  /// by default.
  Future<void> setPin(String pin) async {
    if (!PinHasher.isValidPin(pin)) {
      throw ArgumentError('The PIN must be 6 digits.');
    }
    final wasEnabled = enabled;
    final hashed = await _hash(pin);
    await _store.write(pinKey, hashed);
    _pinHash = hashed;
    if (!wasEnabled) {
      _hidePreview = true;
      await _store.write(hidePreviewKey, 'true');
    }
    await _resetWrongTries();
    _locked = false;
    await _applyPrivacy();
    notifyListeners();
  }

  /// Checks a PIN. Wrong ones count towards the growing wait.
  Future<PinResult> verify(String pin) async {
    final stored = _pinHash;
    if (stored == null) return PinResult.ok;
    if (waitLeft > Duration.zero) return PinResult.wait;

    if (await _verify(pin, stored)) {
      await _resetWrongTries();
      _locked = false;
      notifyListeners();
      return PinResult.ok;
    }

    _wrongTries++;
    final delay = PinLockout.delayAfter(_wrongTries);
    _waitUntil = delay == Duration.zero ? null : _clock().add(delay);
    await _store.write(wrongKey, '$_wrongTries');
    if (_waitUntil == null) {
      await _store.delete(untilKey);
    } else {
      await _store.write(untilKey, '${_waitUntil!.millisecondsSinceEpoch}');
    }
    notifyListeners();
    return PinResult.wrong;
  }

  Future<void> _resetWrongTries() async {
    _wrongTries = 0;
    _waitUntil = null;
    await _store.delete(wrongKey);
    await _store.delete(untilKey);
  }

  /// Turns App lock off.
  Future<void> disable() async {
    for (final key in [pinKey, wrongKey, untilKey, biometricsKey]) {
      await _store.delete(key);
    }
    _pinHash = null;
    _biometrics = false;
    _wrongTries = 0;
    _waitUntil = null;
    _locked = false;
    await _applyPrivacy();
    notifyListeners();
  }

  /// "Forgot PIN": removes the lock. The caller also deletes the safety
  /// plan (it was protected by this PIN) and signs her out.
  Future<void> forgetPin() => disable();

  // ───────────── Biometrics ─────────────

  Future<bool> biometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometrics(bool on) async {
    _biometrics = on;
    await _store.write(biometricsKey, '$on');
    notifyListeners();
  }

  /// Fingerprint / Face unlock. False if cancelled or not available.
  Future<bool> unlockWithBiometrics() async {
    if (!enabled || !_biometrics) return false;
    _authenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return false;
    } on PlatformException {
      return false;
    } finally {
      _authenticating = false;
      _backgroundedAt = null;
    }
    await _resetWrongTries();
    _locked = false;
    notifyListeners();
    return true;
  }

  // ───────────── Settings ─────────────

  Future<void> setLockAfter(LockAfter value) async {
    _lockAfter = value;
    await _store.write(afterKey, value.name);
    notifyListeners();
  }

  Future<void> setHidePreview(bool on) async {
    _hidePreview = on;
    await _store.write(hidePreviewKey, '$on');
    await _applyPrivacy();
    notifyListeners();
  }

  Future<void> _applyPrivacy() => _setSecure(hidePreview);

  // ───────────── Background / foreground ─────────────

  void onBackground() {
    if (_authenticating) return;
    if (enabled) _backgroundedAt ??= _clock();
  }

  void onForeground() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (!enabled || since == null) return;
    if (_clock().difference(since) >= _lockAfter.duration) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Lock now (e.g. after leaving the weather disguise).
  void lockNow() {
    if (!enabled) return;
    _locked = true;
    notifyListeners();
  }

  set disguiseActive(bool value) {
    if (_disguiseActive == value) return;
    _disguiseActive = value;
    notifyListeners();
  }
}
