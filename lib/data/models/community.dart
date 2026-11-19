import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

/// The weekly Small wins thread: `threads/{id}` pins the post `posts/{id}`
/// at the top of Discuss. Started by a moderator.
class SmallWinsThread {
  const SmallWinsThread({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.pinned = true,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool pinned;

  bool isActive(DateTime now) =>
      pinned && !now.isBefore(startsAt) && now.isBefore(endsAt);

  static SmallWinsThread? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null || data['kind'] != 'smallWins') return null;
    final starts = _time(data['startsAt']);
    final ends = _time(data['endsAt']);
    if (starts == null || ends == null) return null;
    return SmallWinsThread(
      id: id,
      title: data['title'] as String? ?? 'Small wins',
      startsAt: starts,
      endsAt: ends,
      pinned: data['pinned'] == true,
    );
  }
}

/// The themed week banner: `themes/current`, set by a moderator.
class ThemedWeek {
  const ThemedWeek({
    required this.title,
    required this.subtitle,
    required this.colorKey,
    required this.guideIds,
    required this.startsAt,
    required this.endsAt,
  });

  final String title;
  final String subtitle;

  /// blush, sage, sand or lavender.
  final String colorKey;

  /// Guides from content/guides.json to read this week.
  final List<String> guideIds;
  final DateTime startsAt;
  final DateTime endsAt;

  bool isActive(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  static ThemedWeek? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final starts = _time(data['startsAt']);
    final ends = _time(data['endsAt']);
    final title = (data['title'] as String? ?? '').trim();
    if (starts == null || ends == null || title.isEmpty) return null;
    return ThemedWeek(
      title: title,
      subtitle: (data['subtitle'] as String? ?? '').trim(),
      colorKey: data['colorKey'] as String? ?? 'blush',
      guideIds:
          (data['guideIds'] as List? ?? const []).whereType<String>().toList(),
      startsAt: starts,
      endsAt: ends,
    );
  }
}
