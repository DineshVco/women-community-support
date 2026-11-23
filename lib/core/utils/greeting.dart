import 'package:flutter/widgets.dart' show StringCharacters;

/// The first word of her sign-up display name, for the Discuss greeting
/// only: trimmed, at most 14 characters (an emoji counts as one, and is
/// never cut in half). Null when there is no name, or when it looks like an
/// email address (her email is never used).
///
/// Shown only on her own phone. It must never be written into posts,
/// replies, aliases, reports, chat profiles or logs (a test checks where
/// it is used).
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

/// The Discuss greeting for [time] (local time), with her [name] if there
/// is one: "Good morning, Bee" (5:00–11:59), "Good afternoon, Bee"
/// (12:00–16:59), "Good evening, Bee" (17:00–21:59) and, late at night
/// (22:00–4:59), "Take a breath, Bee." Without a name: "Good morning",
/// ..., "Take a breath."
String greetingFor(DateTime time, {String? name}) {
  final n = (name == null || name.trim().isEmpty) ? null : name.trim();
  final hour = time.hour;
  String hello(String words) => n == null ? words : '$words, $n';
  if (hour >= 5 && hour < 12) return hello('Good morning');
  if (hour >= 12 && hour < 17) return hello('Good afternoon');
  if (hour >= 17 && hour < 22) return hello('Good evening');
  return n == null ? 'Take a breath.' : 'Take a breath, $n.';
}

/// The small line under the greeting.
const String greetingReassurance = 'You are not alone here.';

/// How many of [timestamps] fall within the last 24 hours of [now].
int countRecent(Iterable<DateTime> timestamps, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(hours: 24));
  return timestamps.where((t) => t.isAfter(cutoff)).length;
}
