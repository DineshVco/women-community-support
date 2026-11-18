import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small key-value store for secrets that never leave the phone:
/// the PIN hash, lockout state, the safety plan and its key.
///
/// An interface so tests can use [MemorySecureStore].
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore / iOS Keychain / WebCrypto via flutter_secure_storage.
///
/// iOS: "this device only", so the Keychain items are never copied to
/// iCloud backups or a new phone. Android: app backup is switched off in
/// AndroidManifest.xml, and the Keystore key cannot leave the phone anyway.
class DeviceSecureStore implements SecureStore {
  DeviceSecureStore()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: false,
        ),
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: false,
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// For tests: forgets everything when the object is dropped.
class MemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
