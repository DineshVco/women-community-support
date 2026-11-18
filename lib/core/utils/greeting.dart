/// The Home greeting for [time]: "Good morning" (5:00–11:59),
/// "Good afternoon" (12:00–16:59), "Good evening" (17:00–21:59), and from
/// 22:00 until 5:00 a gentle "Take a breath, it is late".
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 22) return 'Good evening';
  return 'Take a breath, it is late';
}

/// The small line under the greeting.
const String greetingReassurance = 'You are not alone here.';

/// How many of [timestamps] fall within the last 24 hours of [now].
int countRecent(Iterable<DateTime> timestamps, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(hours: 24));
  return timestamps.where((t) => t.isAfter(cutoff)).length;
}
