import 'package:flutter/painting.dart';

import '../core/security/secure_store.dart';
import 'encrypted_box.dart';

/// "How are you feeling": five moods, from best to hardest.
enum Mood {
  // A calm order of colour, hardest to best: deeper dusty rose, soft rose,
  // sand, light sage, sage. Soft colours only (never red).
  great('Great', Color(0xFFB9CDB8)), // sage
  good('Good', Color(0xFFD5E2D2)), // light sage
  okay('Okay', Color(0xFFEADCC2)), // sand
  low('Low', Color(0xFFEFCACA)), // soft rose
  rough('Rough', Color(0xFFD3A9AE)); // deeper dusty rose

  const Mood(this.label, this.dot);

  final String label;

  /// The small calendar dot. Soft colours only.
  final Color dot;

  /// Low and rough gently offer the help lines.
  bool get offerHelp => this == low || this == rough;
}

/// One day's check-in. A later check-in the same day replaces it.
class MoodEntry {
  const MoodEntry({required this.day, required this.mood, this.note = ''});

  /// Local calendar day (time is ignored).
  final DateTime day;
  final Mood mood;

  /// Optional, one line.
  final String note;

  static String keyFor(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'day': keyFor(day),
    'mood': mood.name,
    'note': note,
  };

  static MoodEntry? fromJson(Map<String, dynamic> json) {
    final mood = Mood.values.where((m) => m.name == json['mood']).firstOrNull;
    final day = DateTime.tryParse(json['day'] as String? ?? '');
    if (mood == null || day == null) return null;
    return MoodEntry(
      day: DateTime(day.year, day.month, day.day),
      mood: mood,
      note: json['note'] as String? ?? '',
    );
  }
}

/// Saves check-ins encrypted, only on this phone.
class MoodStore {
  MoodStore(SecureStore store)
    : _box = EncryptedBox(
        store,
        keyName: 'looma.mood.key',
        dataName: 'looma.mood.data',
      );

  final EncryptedBox _box;

  /// All check-ins, by day key (yyyy-mm-dd).
  Future<Map<String, MoodEntry>> load() async {
    final json = await _box.read();
    if (json is! List) return {};
    final entries = <String, MoodEntry>{};
    for (final item in json) {
      if (item is! Map<String, dynamic>) continue;
      final entry = MoodEntry.fromJson(item);
      if (entry != null) entries[MoodEntry.keyFor(entry.day)] = entry;
    }
    return entries;
  }

  /// Saves (or replaces) the check-in for [entry.day].
  Future<Map<String, MoodEntry>> save(MoodEntry entry) async {
    final entries = await load();
    entries[MoodEntry.keyFor(entry.day)] = entry;
    await _box.write([for (final e in entries.values) e.toJson()]);
    return entries;
  }

  Future<void> clear() => _box.clear();
}

/// Calendar maths for the month view and the weekly line. Weeks start on
/// Monday.
class MoodCalendar {
  MoodCalendar._();

  /// The month grid: `null` for the blank cells before the 1st, then each
  /// day of the month. Its length is a multiple of 7.
  static List<DateTime?> monthGrid(int year, int month) {
    final first = DateTime(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = first.weekday - DateTime.monday; // 0..6
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(year, month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  /// Monday of the week [day] is in.
  static DateTime weekStart(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
  }

  /// How many days this week (Monday to [today]) have a check-in.
  static int daysLoggedThisWeek(
    Map<String, MoodEntry> entries,
    DateTime today,
  ) {
    final start = weekStart(today);
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (day.isAfter(today)) break;
      if (entries.containsKey(MoodEntry.keyFor(day))) count++;
    }
    return count;
  }

  /// A gentle sentence, never a score or a streak.
  static String weeklyLine(int days) => switch (days) {
    0 => 'No check-ins yet this week. Whenever you like.',
    1 => 'You logged 1 day this week.',
    _ => 'You logged $days days this week.',
  };
}
