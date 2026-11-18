import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../core/security/secure_store.dart';

/// Someone she can contact.
class SafeContact {
  const SafeContact({
    required this.name,
    required this.number,
    this.anytime = false,
  });

  final String name;
  final String number;

  /// Can be called at any time, day or night.
  final bool anytime;

  Map<String, dynamic> toJson() => {
    'name': name,
    'number': number,
    'anytime': anytime,
  };

  factory SafeContact.fromJson(Map<String, dynamic> json) => SafeContact(
    name: json['name'] as String? ?? '',
    number: json['number'] as String? ?? '',
    anytime: json['anytime'] == true,
  );
}

/// Her private safety plan. Lives ONLY on this phone (see [SafetyPlanStore]).
class SafetyPlan {
  const SafetyPlan({
    this.contacts = const [],
    this.safePlace = '',
    this.codeWord = '',
    this.ready = const {},
    this.notes = '',
  });

  final List<SafeContact> contacts;
  final String safePlace;
  final String codeWord;

  /// Ids from [readyItems] she has ticked.
  final Set<String> ready;
  final String notes;

  /// "Things to keep ready".
  static const List<(String, String)> readyItems = [
    ('id', 'ID'),
    ('money', 'Money'),
    ('charger', 'Phone charger'),
    ('medicine', 'Medicine'),
    ('keys', 'Keys'),
    ('documents', 'Documents'),
  ];

  bool get isEmpty =>
      contacts.isEmpty &&
      safePlace.isEmpty &&
      codeWord.isEmpty &&
      ready.isEmpty &&
      notes.isEmpty;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'contacts': [for (final c in contacts) c.toJson()],
    'safePlace': safePlace,
    'codeWord': codeWord,
    'ready': ready.toList()..sort(),
    'notes': notes,
  };

  factory SafetyPlan.fromJson(Map<String, dynamic> json) => SafetyPlan(
    contacts: [
      for (final c in (json['contacts'] as List? ?? const []))
        if (c is Map<String, dynamic>) SafeContact.fromJson(c),
    ],
    safePlace: json['safePlace'] as String? ?? '',
    codeWord: json['codeWord'] as String? ?? '',
    ready: {...(json['ready'] as List? ?? const []).whereType<String>()},
    notes: json['notes'] as String? ?? '',
  );
}

/// Saves the safety plan encrypted (AES-256-GCM) in secure storage on this
/// phone. The key is random and also kept in secure storage. Nothing is
/// ever sent to Firestore or any server, and it is not included in backups
/// (iOS: "this device only" Keychain items; Android: app backup is off).
/// If she loses the phone, the plan is gone too.
class SafetyPlanStore {
  SafetyPlanStore(this._store);

  final SecureStore _store;
  final AesGcm _cipher = AesGcm.with256bits();

  static const String keyKey = 'looma.plan.key';
  static const String dataKey = 'looma.plan.data';

  Future<SecretKey> _key({required bool create}) async {
    final saved = await _store.read(keyKey);
    if (saved != null) return SecretKey(base64Decode(saved));
    if (!create) throw StateError('No key yet.');
    final key = await _cipher.newSecretKey();
    await _store.write(keyKey, base64Encode(await key.extractBytes()));
    return key;
  }

  Future<SafetyPlan> load() async {
    final data = await _store.read(dataKey);
    if (data == null) return const SafetyPlan();
    final box = SecretBox.fromConcatenation(
      base64Decode(data),
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: await _key(create: false),
    );
    return SafetyPlan.fromJson(
      jsonDecode(utf8.decode(clear)) as Map<String, dynamic>,
    );
  }

  Future<void> save(SafetyPlan plan) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(plan.toJson())),
      secretKey: await _key(create: true),
    );
    await _store.write(dataKey, base64Encode(box.concatenation()));
  }

  /// "Clear my plan": deletes the plan and its key.
  Future<void> clear() async {
    await _store.delete(dataKey);
    await _store.delete(keyKey);
  }
}
