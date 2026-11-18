import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Turns a 6-digit PIN into a salted hash. Only the hash and the salt are
/// stored (in secure storage), never the PIN itself.
///
/// PBKDF2-HMAC-SHA256 with a random 16-byte salt. Stored as
/// `pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>`.
class PinHasher {
  PinHasher._();

  static const int pinLength = 6;
  static const int iterations = 20000;
  static const String _scheme = 'pbkdf2-sha256';

  static bool isValidPin(String pin) => RegExp(r'^[0-9]{6}$').hasMatch(pin);

  static Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  /// The string to store for [pin].
  static String hash(String pin, {Uint8List? salt, int rounds = iterations}) {
    final s = salt ?? newSalt();
    final derived = pbkdf2(utf8.encode(pin), s, rounds);
    return '$_scheme\$$rounds\$${base64Encode(s)}\$${base64Encode(derived)}';
  }

  /// True when [pin] matches the [stored] hash. Compares in constant time.
  static bool verify(String pin, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1) return false;
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = pbkdf2(utf8.encode(pin), salt, rounds);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// PBKDF2 with HMAC-SHA256, one 32-byte block (RFC 8018).
  static Uint8List pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }
}

/// How long she must wait after wrong PINs. Grows with each mistake:
/// 1-2 wrong: no wait, 3: 5 s, 4: 15 s, 5 or more: 1 minute.
class PinLockout {
  PinLockout._();

  static Duration delayAfter(int wrongTries) {
    if (wrongTries >= 5) return const Duration(minutes: 1);
    if (wrongTries == 4) return const Duration(seconds: 15);
    if (wrongTries == 3) return const Duration(seconds: 5);
    return Duration.zero;
  }
}
