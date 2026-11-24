import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'package:flutter/material.dart'
    show BuildContext, ScaffoldMessenger, SnackBar, Text;

import '../core/security/secure_store.dart';

/// Private data that stays ONLY on this phone: the safety plan, the mood
/// log and the journal.
///
/// The JSON is encrypted with AES-256-GCM. The random key and the encrypted
/// data both live in secure storage (Android Keystore / iOS Keychain "this
/// device only"), so nothing readable is ever written to disk, sent to a
/// server or included in phone backups (Android backup is switched off).
/// If she loses or resets the phone, the data is gone too.
class EncryptedBox {
  EncryptedBox(this._store, {required this.keyName, required this.dataName});

  final SecureStore _store;
  final String keyName;
  final String dataName;
  final AesGcm _cipher = AesGcm.with256bits();

  /// On the web, "secure storage" is ordinary browser storage. Looma turns
  /// these private tools off there and says why.
  static bool get supported => !(debugPretendWeb ?? kIsWeb);

  /// Tests set this to true to see the web version.
  @visibleForTesting
  static bool? debugPretendWeb;

  static const String webNote =
      'Available in the phone app. Browsers cannot keep it safely locked.';

  /// On the web, says why instead of opening a private tool.
  static bool explainOnWeb(BuildContext context) {
    if (supported) return false;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(webNote)));
    return true;
  }

  Future<SecretKey> _key({required bool create}) async {
    final saved = await _store.read(keyName);
    if (saved != null) return SecretKey(base64Decode(saved));
    if (!create) throw StateError('No key yet.');
    final key = await _cipher.newSecretKey();
    await _store.write(keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  /// The saved JSON, or null when nothing is saved yet.
  Future<Object?> read() async {
    final data = await _store.read(dataName);
    if (data == null) return null;
    final box = SecretBox.fromConcatenation(
      base64Decode(data),
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: await _key(create: false),
    );
    return jsonDecode(utf8.decode(clear));
  }

  Future<void> write(Object json) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(json)),
      secretKey: await _key(create: true),
    );
    await _store.write(dataName, base64Encode(box.concatenation()));
  }

  /// Deletes the data and its key.
  Future<void> clear() async {
    await _store.delete(dataName);
    await _store.delete(keyName);
  }
}
