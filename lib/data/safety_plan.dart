import '../core/security/secure_store.dart';
import 'encrypted_box.dart';

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
/// phone (see [EncryptedBox]). Nothing is ever sent to Firestore or any
/// server, and it is not included in backups. If she loses the phone, the
/// plan is gone too.
class SafetyPlanStore {
  SafetyPlanStore(SecureStore store)
    : _box = EncryptedBox(store, keyName: keyKey, dataName: dataKey);

  final EncryptedBox _box;

  static const String keyKey = 'looma.plan.key';
  static const String dataKey = 'looma.plan.data';

  Future<SafetyPlan> load() async {
    final json = await _box.read();
    if (json == null) return const SafetyPlan();
    return SafetyPlan.fromJson(json as Map<String, dynamic>);
  }

  Future<void> save(SafetyPlan plan) => _box.write(plan.toJson());

  /// "Clear my plan": deletes the plan and its key.
  Future<void> clear() => _box.clear();
}
