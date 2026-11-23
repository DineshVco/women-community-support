import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The four parts of her day (local time), for "Today for you" on Care.
enum TodaySlot {
  morning('Morning'), // 5:00–11:59: a gentle start
  afternoon('Afternoon'), // 12:00–16:59: a reset
  evening('Evening'), // 17:00–21:59: wind down
  night('Late night'); // 22:00–4:59: sleep help, quieter colours

  const TodaySlot(this.label);

  final String label;

  static TodaySlot forTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return TodaySlot.morning;
    if (hour >= 12 && hour < 17) return TodaySlot.afternoon;
    if (hour >= 17 && hour < 22) return TodaySlot.evening;
    return TodaySlot.night;
  }
}

/// Where a suggestion leads.
enum TodayTargetKind { breathe, ground, journal, guide }

class TodaySuggestion {
  const TodaySuggestion({
    required this.id,
    required this.title,
    required this.text,
    required this.target,
    this.verified = false,
  });

  final String id;
  final String title;
  final String text;

  /// "breathe", "ground", "journal" or "guide:" plus a guide id.
  final String target;

  /// True only after Najwa has checked the wording.
  final bool verified;

  TodayTargetKind? get kind => switch (target) {
    'breathe' => TodayTargetKind.breathe,
    'ground' => TodayTargetKind.ground,
    'journal' => TodayTargetKind.journal,
    _ when target.startsWith('guide:') => TodayTargetKind.guide,
    _ => null,
  };

  String? get guideId =>
      kind == TodayTargetKind.guide ? target.substring('guide:'.length) : null;

  /// What the card's action says.
  String get actionLabel => switch (kind) {
    TodayTargetKind.breathe => 'Breathe with the cat',
    TodayTargetKind.ground => 'Try 5-4-3-2-1',
    TodayTargetKind.journal => 'Open your journal',
    TodayTargetKind.guide => 'Read the guide',
    null => 'Open',
  };

  static TodaySuggestion? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final s = TodaySuggestion(
      id: json['id'] as String? ?? '',
      title: (json['title'] as String? ?? '').trim(),
      text: (json['text'] as String? ?? '').trim(),
      target: json['target'] as String? ?? '',
      verified: json['verified'] == true,
    );
    if (s.id.isEmpty || s.title.isEmpty || s.kind == null) return null;
    return s;
  }
}

/// content/today_for_you.json: 3 to 5 suggestions per time slot.
class TodayForYou {
  const TodayForYou(this.slots);

  static const TodayForYou empty = TodayForYou({});

  final Map<TodaySlot, List<TodaySuggestion>> slots;

  static TodayForYou parse(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final raw = map['slots'] as Map<String, dynamic>? ?? const {};
    return TodayForYou({
      for (final slot in TodaySlot.values)
        slot: [
          for (final item in raw[slot.name] as List? ?? const [])
            if (TodaySuggestion.fromJson(item) case final s?) s,
        ],
    });
  }

  /// The day a moment belongs to. After midnight, until 5:00, it still
  /// counts as the night before, so the late-night card does not change
  /// at 00:00.
  static DateTime dayOf(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return now.hour < 5 ? DateTime(d.year, d.month, d.day - 1) : d;
  }

  /// Today's suggestion for [now]: the same one all through the slot. In
  /// release builds only checked (verified) suggestions are shown; debug
  /// builds (for Najwa) show drafts too. Null if there is none.
  TodaySuggestion? pick(DateTime now, {bool includeDrafts = kDebugMode}) {
    final list = [
      for (final s
          in slots[TodaySlot.forTime(now)] ?? const <TodaySuggestion>[])
        if (includeDrafts || s.verified) s,
    ];
    if (list.isEmpty) return null;
    final day = dayOf(now);
    final index =
        DateTime.utc(
          day.year,
          day.month,
          day.day,
        ).difference(DateTime.utc(2024, 1, 1)).inDays;
    return list[index % list.length];
  }
}
