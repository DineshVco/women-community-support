import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../core/security/secure_store.dart';
import 'encrypted_box.dart';

/// One private journal note.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.prompt,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The prompt she started from, if any.
  final String? prompt;

  /// First line, for the list.
  String get title {
    final first = text.trim().split('\n').first.trim();
    if (first.isNotEmpty) return first;
    return prompt ?? 'Untitled note';
  }

  JournalEntry copyWith({String? text, String? prompt, DateTime? updatedAt}) =>
      JournalEntry(
        id: id,
        text: text ?? this.text,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        prompt: prompt ?? this.prompt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (prompt != null) 'prompt': prompt,
  };

  static JournalEntry? fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final id = json['id'] as String?;
    if (created == null || updated == null || id == null) return null;
    return JournalEntry(
      id: id,
      text: json['text'] as String? ?? '',
      createdAt: created,
      updatedAt: updated,
      prompt: json['prompt'] as String?,
    );
  }
}

/// Saves the journal encrypted, only on this phone. Newest first.
class JournalStore {
  JournalStore(SecureStore store, {DateTime Function()? clock})
    : _box = EncryptedBox(
        store,
        keyName: 'looma.journal.key',
        dataName: 'looma.journal.data',
      ),
      _clock = clock ?? DateTime.now;

  final EncryptedBox _box;
  final DateTime Function() _clock;

  Future<List<JournalEntry>> load() async {
    final json = await _box.read();
    if (json is! List) return [];
    final entries =
        [
          for (final item in json)
            if (item is Map<String, dynamic>) JournalEntry.fromJson(item),
        ].whereType<JournalEntry>().toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<void> _saveAll(List<JournalEntry> entries) =>
      _box.write([for (final e in entries) e.toJson()]);

  /// Adds a new note and returns it.
  Future<JournalEntry> add(String text, {String? prompt}) async {
    final now = _clock();
    final random = Random.secure();
    final entry = JournalEntry(
      id: '${now.microsecondsSinceEpoch}-${random.nextInt(1 << 30)}',
      text: text,
      createdAt: now,
      updatedAt: now,
      prompt: prompt,
    );
    await _saveAll([entry, ...await load()]);
    return entry;
  }

  Future<void> update(String id, String text) async {
    final entries = await load();
    await _saveAll([
      for (final e in entries)
        e.id == id ? e.copyWith(text: text, updatedAt: _clock()) : e,
    ]);
  }

  Future<void> delete(String id) async {
    final entries = await load();
    await _saveAll(entries.where((e) => e.id != id).toList());
  }

  Future<void> clear() => _box.clear();
}

/// Writing prompts from content/guides.json (bundled with the app).
class JournalPrompts {
  JournalPrompts._();

  static const List<String> fallback = ['What is on my mind right now?'];

  static Future<List<String>> load() async {
    try {
      final raw = await rootBundle.loadString('content/guides.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final prompts = (json['journal_prompts'] as List).whereType<String>();
      return prompts.isEmpty ? fallback : prompts.toList();
    } catch (_) {
      return fallback;
    }
  }
}
