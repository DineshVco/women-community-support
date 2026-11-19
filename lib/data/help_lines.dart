import 'package:flutter/widgets.dart';

import 'content_library.dart';

/// The Care tab's help lines, made from content/directory.json, so the
/// Care tab, Get help and the Directory can never show different numbers.
///
/// Only the grouping (which heading each entry sits under) lives in code.
/// Anything in the file that is not listed here still shows, under
/// "More help", so nothing is ever silently left out. The 999 entry is the
/// "In danger right now?" card instead.
class HelpLineGroup {
  const HelpLineGroup({required this.title, required this.entries});

  final String title;
  final List<DirectoryEntry> entries;

  /// The earliest "last checked" date in the group, or null if any entry
  /// has not been checked yet.
  DateTime? get lastChecked {
    DateTime? earliest;
    for (final e in entries) {
      final d = e.lastChecked;
      if (d == null) return null;
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    return earliest;
  }
}

class HelpLines {
  HelpLines._();

  static const String emergencyId = 'emergency';

  static const List<(String, List<String>)> layout = [
    ('Talk to someone now', ['befrienders-kl', 'talian-kasih']),
    ('Women and family support', ['wao-hotline', 'wao-tina']),
  ];

  static const String otherTitle = 'More help';

  static List<HelpLineGroup> groupsFrom(ContentLibrary library) {
    final byId = {for (final e in library.directory) e.id: e};
    final used = <String>{emergencyId};
    final groups = <HelpLineGroup>[];
    for (final (title, ids) in layout) {
      final entries = [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
      used.addAll(ids);
      if (entries.isNotEmpty) {
        groups.add(HelpLineGroup(title: title, entries: entries));
      }
    }
    final rest = library.directory.where((e) => !used.contains(e.id)).toList();
    if (rest.isNotEmpty) {
      groups.add(HelpLineGroup(title: otherTitle, entries: rest));
    }
    return groups;
  }
}

/// Makes the bundled library (loaded once at start-up) available to every
/// screen without waiting.
class ContentScope extends InheritedWidget {
  const ContentScope({super.key, required this.library, required super.child});

  final ContentLibrary library;

  static ContentLibrary? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ContentScope>()?.library;

  @override
  bool updateShouldNotify(ContentScope oldWidget) =>
      library != oldWidget.library;
}

/// Builds with the library: straight away when it was loaded at start-up,
/// otherwise after loading it.
class WithContent extends StatefulWidget {
  const WithContent({super.key, required this.builder});

  final Widget Function(BuildContext context, ContentLibrary library) builder;

  @override
  State<WithContent> createState() => _WithContentState();
}

class _WithContentState extends State<WithContent> {
  Future<ContentLibrary>? _load;

  @override
  Widget build(BuildContext context) {
    final ready = ContentScope.maybeOf(context);
    if (ready != null) return widget.builder(context, ready);
    _load ??= ContentLibrary.load();
    return FutureBuilder<ContentLibrary>(
      future: _load,
      builder: (context, snapshot) {
        final library = snapshot.data;
        if (library == null) return const SizedBox.shrink();
        return widget.builder(context, library);
      },
    );
  }
}
