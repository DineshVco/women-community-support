import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/security/secure_store.dart';

/// The offline library: guides and the help directory, bundled with the app
/// from content/guides.json and content/directory.json. Nothing is fetched
/// from the internet.

/// "This is general information, not medical or legal advice." ends every
/// guide.
const String guideFooter =
    'This is general information, not medical or legal advice.';

/// Marks a fact Najwa must check with a trusted source before the booth.
const String verifyMark = '[VERIFY';

class GuideSection {
  const GuideSection({required this.heading, required this.text});

  final String heading;
  final String text;

  bool get needsChecking =>
      text.contains(verifyMark) || heading.contains(verifyMark);
}

class Guide {
  const Guide({
    required this.id,
    required this.title,
    required this.category,
    required this.readMinutes,
    required this.sections,
    required this.verified,
  });

  final String id;
  final String title;

  /// Same ids as post categories (health_wellness, education, ...).
  final String category;
  final int readMinutes;
  final List<GuideSection> sections;

  /// Najwa has read and checked it.
  final bool verified;

  /// Still has a [VERIFY] mark somewhere.
  bool get needsChecking =>
      title.contains(verifyMark) || sections.any((s) => s.needsChecking);

  /// Ready to show to everyone: checked, and no [VERIFY] left.
  bool get publishable => verified && !needsChecking;

  /// Safety guides also show "In danger? Call 999".
  bool get aboutSafety => category == 'personal_safety';

  String get categoryLabel => GuideCategories.label(category);
  Color get categoryColor => GuideCategories.color(category);

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (categoryLabel.toLowerCase().contains(q)) return true;
    return sections.any(
      (s) =>
          s.heading.toLowerCase().contains(q) ||
          s.text.toLowerCase().contains(q),
    );
  }

  factory Guide.fromJson(Map<String, dynamic> json) => Guide(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String? ?? '',
    readMinutes: (json['readMinutes'] as num?)?.toInt() ?? 2,
    verified: json['verified'] == true,
    sections: [
      for (final s in json['sections'] as List? ?? const [])
        if (s is Map<String, dynamic>)
          GuideSection(
            heading: s['h'] as String? ?? '',
            text: s['p'] as String? ?? '',
          ),
    ],
  );
}

/// Soft category colours, only for small dots and labels.
class GuideCategories {
  GuideCategories._();

  static const List<(String, String, Color)> all = [
    ('health_wellness', 'Health', Color(0xFFBFD0C1)), // sage
    ('education', 'Study', Color(0xFFE6D3B3)), // sand
    ('career_development', 'Work', Color(0xFFCFC9DB)), // lavender-grey
    ('personal_safety', 'Safety', Color(0xFFE9B8B3)), // blush
  ];

  static String label(String id) =>
      all.where((c) => c.$1 == id).map((c) => c.$2).firstOrNull ?? 'Guide';

  static Color color(String id) =>
      all.where((c) => c.$1 == id).map((c) => c.$3).firstOrNull ??
      const Color(0xFFCFC9DB);
}

/// One organisation or help line. Only entries from directory.json.
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.name,
    required this.helps,
    required this.verified,
    this.number,
    this.website,
    this.language,
    this.hours,
    this.lastChecked,
  });

  final String id;
  final String name;

  /// What they help with.
  final String helps;
  final String? number;
  final String? website;
  final String? language;

  /// Shown only when [verified] (never guessed).
  final String? hours;
  final DateTime? lastChecked;
  final bool verified;

  String? get shownHours => verified ? hours : null;

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return DirectoryEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      helps: json['helps'] as String? ?? '',
      verified: json['verified'] == true,
      number: text('number'),
      website: text('website'),
      language: text('language'),
      hours: text('hours'),
      lastChecked: DateTime.tryParse(json['lastChecked'] as String? ?? ''),
    );
  }
}

class ContentLibrary {
  const ContentLibrary({
    required this.guides,
    required this.directory,
    required this.journalPrompts,
  });

  /// Every guide in the file, checked or not.
  final List<Guide> guides;
  final List<DirectoryEntry> directory;
  final List<String> journalPrompts;

  static const String guidesAsset = 'content/guides.json';
  static const String directoryAsset = 'content/directory.json';

  static Future<ContentLibrary> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return parse(
      guidesJson: await b.loadString(guidesAsset),
      directoryJson: await b.loadString(directoryAsset),
    );
  }

  static ContentLibrary parse({
    required String guidesJson,
    required String directoryJson,
  }) {
    final g = jsonDecode(guidesJson) as Map<String, dynamic>;
    final d = jsonDecode(directoryJson) as Map<String, dynamic>;
    return ContentLibrary(
      guides: [
        for (final item in g['guides'] as List? ?? const [])
          if (item is Map<String, dynamic>) Guide.fromJson(item),
      ],
      journalPrompts:
          (g['journal_prompts'] as List? ?? const [])
              .whereType<String>()
              .toList(),
      directory: [
        for (final item in d['entries'] as List? ?? const [])
          if (item is Map<String, dynamic>) DirectoryEntry.fromJson(item),
      ],
    );
  }

  /// Guides she may see. In release builds: only checked guides with no
  /// [VERIFY] mark left. Debug builds (for Najwa) also show drafts.
  List<Guide> visibleGuides({bool includeDrafts = kDebugMode}) =>
      guides.where((g) => includeDrafts || g.publishable).toList();

  List<Guide> search(String query, {bool includeDrafts = kDebugMode}) =>
      visibleGuides(
        includeDrafts: includeDrafts,
      ).where((g) => g.matches(query)).toList();
}

/// Bookmarked guides, kept on this phone in secure storage (a list of
/// guide ids). Not in ordinary settings, which can end up in backups.
class GuideBookmarks {
  GuideBookmarks(this._store);

  final SecureStore _store;
  static const String key = 'looma.guides.bookmarks';

  Future<Set<String>> load() async {
    try {
      final raw = await _store.read(key);
      if (raw == null) return {};
      return {...(jsonDecode(raw) as List).whereType<String>()};
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> toggle(String id) async {
    final ids = await load();
    if (!ids.remove(id)) ids.add(id);
    await _store.write(key, jsonEncode(ids.toList()..sort()));
    return ids;
  }

  Future<void> clear() => _store.delete(key);
}
