import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Warm plain lines from content/microcopy.json (Najwa can edit the file).
/// Loaded once at start-up; until then, or if the file cannot be read, the
/// built-in copies below are used. A test keeps them the same as the file.
class Microcopy {
  Microcopy._();

  static const String asset = 'content/microcopy.json';

  /// The "empty" lines, exactly as in the file.
  static const Map<String, String> builtInEmpty = {
    'feed': 'Nothing here yet. Be the first to say hello.',
    'search': 'We could not find that. Try another word.',
    'saved': 'Nothing saved yet. Tap the bookmark on a post you want to keep.',
    'my_posts': 'You have not posted yet. Whenever you are ready.',
    'activity': 'No news yet. We will tell you when someone replies.',
    'connect':
        'No one here yet. Turn on Open to chat in Me so others can find you.',
  };

  static Map<String, String> _empty = builtInEmpty;

  static Future<void> load([AssetBundle? bundle]) async {
    try {
      final json = await (bundle ?? rootBundle).loadString(asset);
      _empty = parseEmpty(json);
    } catch (_) {
      _empty = builtInEmpty; // keep the built-in lines
    }
  }

  /// The "empty" map from the file; anything missing falls back.
  static Map<String, String> parseEmpty(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final empty = map['empty'];
    return {
      ...builtInEmpty,
      if (empty is Map)
        for (final e in empty.entries)
          if (e.value is String && (e.value as String).trim().isNotEmpty)
            e.key.toString(): (e.value as String).trim(),
    };
  }

  static String empty(String key) => _empty[key] ?? builtInEmpty[key] ?? '';

  /// No posts at all.
  static String get emptyFeed => empty('feed');

  /// Search or filter found nothing.
  static String get emptySearch => empty('search');

  /// No saved posts.
  static String get emptySaved => empty('saved');

  /// She has not posted yet.
  static String get emptyMyPosts => empty('my_posts');
}
