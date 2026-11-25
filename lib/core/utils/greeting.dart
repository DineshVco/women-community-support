import 'package:flutter/widgets.dart' show StringCharacters;

/// The first word of her Google name, for the Discuss greeting only:
/// trimmed, at most 14 characters (an emoji counts as one, and is never cut
/// in half). Null when there is no name, or when it looks like an email
/// address (her email is never used).
///
/// The name she chose herself ("What should we call you?", see
/// [cleanCallName]) comes first. Either is shown only to her. Neither may be
/// written into posts, replies, aliases, reports, chat profiles or logs (a
/// test checks where they are used).
String? greetingName(String? displayName) {
  final raw = displayName?.trim() ?? '';
  if (raw.isEmpty || raw.contains('@')) return null;
  final first = raw.split(RegExp(r'\s+')).first;
  final chars = first.characters;
  final name =
      chars.length > maxGreetingNameLength
          ? chars.take(maxGreetingNameLength).toString()
          : first;
  return name.isEmpty ? null : name;
}

const int maxGreetingNameLength = 14;

/// The longest name she can choose ("What should we call you?").
const int maxCallNameLength = 20;

/// Her chosen first name or nickname, tidied: trimmed, inner spaces
/// collapsed, 1 to [maxCallNameLength] characters (an emoji counts as one).
/// Null when it is empty, too long, or looks like an email address.
String? cleanCallName(String? raw) {
  final name = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.contains('@')) return null;
  if (name.characters.length > maxCallNameLength) return null;
  return name;
}

/// The Discuss greeting for [time] (the phone's local time), with her
/// [name] if there is one: "Good morning, Bee" (5:00–11:59), "Good
/// afternoon, Bee" (12:00–17:59) and "Good evening, Bee" (18:00–4:59).
/// Without a name: just "Good morning", "Good afternoon" or "Good evening".
String greetingFor(DateTime time, {String? name}) {
  final n = (name == null || name.trim().isEmpty) ? null : name.trim();
  final hour = time.hour;
  final words =
      hour >= 5 && hour < 12
          ? 'Good morning'
          : hour >= 12 && hour < 18
          ? 'Good afternoon'
          : 'Good evening';
  return n == null ? words : '$words, $n';
}

/// The small line under the greeting.
const String greetingReassurance = 'You are not alone here.';

/// How many of [timestamps] fall within the last 24 hours of [now].
int countRecent(Iterable<DateTime> timestamps, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(hours: 24));
  return timestamps.where((t) => t.isAfter(cutoff)).length;
}
