import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/constants/helplines.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/data/help_lines.dart';
import 'package:women_community_support/presentation/screens/care/directory_screen.dart';
import 'package:women_community_support/presentation/screens/care/guides_screen.dart';
import 'package:women_community_support/presentation/screens/help_screen.dart';

/// The real files bundled with the app.
ContentLibrary _realLibrary() => ContentLibrary.parse(
  guidesJson: File('content/guides.json').readAsStringSync(),
  directoryJson: File('content/directory.json').readAsStringSync(),
);

/// A small library with every kind of guide.
ContentLibrary _sampleLibrary() => ContentLibrary.parse(
  guidesJson: jsonEncode({
    'journal_prompts': ['What is on my mind?'],
    'guides': [
      {
        'id': 'ready',
        'verified': true,
        'category': 'education',
        'title': 'Exam stress: small steps',
        'readMinutes': 2,
        'sections': [
          {'h': 'Start small', 'p': 'Study for 25 minutes, then rest.'},
        ],
      },
      {
        'id': 'safe-travel',
        'verified': true,
        'category': 'personal_safety',
        'title': 'Travelling alone',
        'readMinutes': 3,
        'sections': [
          {'h': 'Before you go', 'p': 'Tell someone your route.'},
        ],
      },
      {
        'id': 'still-marked',
        'verified': true,
        'category': 'personal_safety',
        'title': 'Online pressure',
        'readMinutes': 2,
        'sections': [
          {'h': 'Legal help', 'p': '[VERIFY: the law and where to report]'},
        ],
      },
      {
        'id': 'draft',
        'verified': false,
        'category': 'health_wellness',
        'title': 'Low mood',
        'readMinutes': 2,
        'sections': [
          {'h': 'Small things', 'p': 'Sunlight and a short walk.'},
        ],
      },
    ],
  }),
  directoryJson: jsonEncode({
    'entries': [
      {
        'id': 'checked',
        'name': 'Checked line',
        'number': '111',
        'helps': 'Listening',
        'verified': true,
        'hours': '24 hours',
        'lastChecked': '2026-11-01',
      },
      {
        'id': 'unchecked',
        'name': 'Unchecked line',
        'number': '222',
        'helps': 'Advice',
        'verified': false,
        'hours': 'Mon to Fri',
        'lastChecked': null,
      },
    ],
  }),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The floating cat on empty states loops, so no pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ───────────────────────── Loading ─────────────────────────

  group('content files', () {
    test('guides.json and directory.json load', () {
      final library = _realLibrary();
      expect(library.guides, hasLength(8));
      expect(library.journalPrompts, hasLength(5));
      expect(library.directory, hasLength(5));
      for (final g in library.guides) {
        expect(g.sections, isNotEmpty, reason: g.id);
        expect(g.title, isNotEmpty);
      }
    });

    test('nothing is shown to users until Najwa checks it', () {
      // Every guide in the file is still unverified.
      expect(_realLibrary().visibleGuides(includeDrafts: false), isEmpty);
    });

    test('the guide on online pressure is held back by its [VERIFY] mark', () {
      final guide = _realLibrary().guides.firstWhere(
        (g) => g.id == 'online-pressure',
      );
      expect(guide.needsChecking, isTrue);
    });

    test('directory numbers match the Care help lines (no drift)', () {
      final library = _realLibrary();
      final care = [
        for (final g in HelpLines.groupsFrom(library)) ...g.entries,
      ];
      // The Care tab shows exactly the file's entries (999 is its own card),
      // with the same numbers.
      expect(
        care.map((e) => e.id).toSet(),
        library.directory.map((e) => e.id).toSet()..remove('emergency'),
      );
      final byId = {for (final e in library.directory) e.id: e};
      for (final e in care) {
        expect(e.number, byId[e.id]!.number);
        expect(e.sms, byId[e.id]!.sms);
        expect(e.whatsapp, byId[e.id]!.whatsapp);
      }
      // The built-in 999 (danger card) matches the file.
      expect(byId['emergency']!.number, Helplines.emergency.number);
    });
  });

  // ───────────────────────── What is visible ─────────────────────────

  group('visibility', () {
    test('only checked guides with no [VERIFY] left', () {
      final shown = _sampleLibrary().visibleGuides(includeDrafts: false);
      expect(shown.map((g) => g.id), ['ready', 'safe-travel']);
    });

    test('debug builds also show drafts (for Najwa)', () {
      final shown = _sampleLibrary().visibleGuides(includeDrafts: true);
      expect(shown, hasLength(4));
    });

    test('hours are shown only for checked directory entries', () {
      final d = _sampleLibrary().directory;
      expect(d[0].shownHours, '24 hours');
      expect(d[1].shownHours, isNull);
      expect(d[0].lastChecked, DateTime(2026, 11, 1));
      expect(d[1].lastChecked, isNull);
    });
  });

  // ───────────────────────── Search ─────────────────────────

  group('search', () {
    final library = _sampleLibrary();

    test('finds words in titles and in the text, any case', () {
      expect(library.search('EXAM', includeDrafts: false).map((g) => g.id), [
        'ready',
      ]);
      expect(library.search('route', includeDrafts: false).map((g) => g.id), [
        'safe-travel',
      ]);
    });

    test('finds by category name', () {
      expect(library.search('safety', includeDrafts: false).map((g) => g.id), [
        'safe-travel',
      ]);
    });

    test('never returns hidden guides', () {
      expect(library.search('sunlight', includeDrafts: false), isEmpty);
      expect(library.search('sunlight', includeDrafts: true), hasLength(1));
    });

    test('an empty search shows everything visible', () {
      expect(library.search('  ', includeDrafts: false), hasLength(2));
    });
  });

  // ───────────────────────── Screens ─────────────────────────

  group('Guides screen', () {
    testWidgets('release build with nothing checked: a kind message', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GuidesScreen(
            library: _realLibrary(),
            bookmarks: GuideBookmarks(MemorySecureStore()),
            includeDrafts: false,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text(GuidesScreen.noneYet), findsOneWidget);
    });

    testWidgets('list, search, open, footer, bookmark and Saved', (
      tester,
    ) async {
      _phone(tester);
      final bookmarks = GuideBookmarks(MemorySecureStore());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GuidesScreen(
            library: _sampleLibrary(),
            bookmarks: bookmarks,
            includeDrafts: false,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Exam stress: small steps'), findsOneWidget);
      expect(find.text('Travelling alone'), findsOneWidget);
      expect(find.text('Low mood'), findsNothing);
      expect(find.text('Study · 2 min read'), findsOneWidget);

      // Search.
      await tester.enterText(find.byType(EditableText), 'route');
      await tester.pump();
      expect(find.text('Exam stress: small steps'), findsNothing);
      expect(find.text('Travelling alone'), findsOneWidget);

      // Open the safety guide.
      await tester.tap(find.text('Travelling alone'));
      await _settle(tester);
      expect(find.text('Before you go'), findsOneWidget);
      expect(find.text(guideFooter), findsOneWidget);
      expect(find.text('In danger? Call 999'), findsOneWidget);

      // Bookmark it, go back, and find it under Saved.
      await tester.tap(find.bySemanticsLabel('Bookmark'));
      await tester.pump();
      expect(await bookmarks.load(), {'safe-travel'});
      await tester.pageBack();
      await _settle(tester);
      await tester.enterText(find.byType(EditableText), '');
      await tester.tap(find.text('Saved'));
      await _settle(tester);
      expect(find.text('Travelling alone'), findsOneWidget);
      expect(find.text('Exam stress: small steps'), findsNothing);
    });

    testWidgets('non-safety guides have no 999 card, but the footer', (
      tester,
    ) async {
      _phone(tester);
      final guide = _sampleLibrary().guides.first;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GuideDetailScreen(
            guide: guide,
            bookmarks: GuideBookmarks(MemorySecureStore()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('In danger? Call 999'), findsNothing);
      expect(find.text(guideFooter), findsOneWidget);
    });
  });

  group('messaging and sources', () {
    test('SMS and WhatsApp numbers are read from the file', () {
      final e = _messagingLibrary().directory.first;
      expect(e.number, isNull);
      expect(e.canMessage, isTrue);
      expect(e.copyNumber, '012-345 6789');
      expect(e.shownSource, 'example.org.my');
      expect(e.shownHours, '9 am to 5 pm');
    });

    test('a "[add official source]" placeholder is never shown', () {
      expect(_messagingLibrary().directory.last.shownSource, isNull);
    });

    test('WhatsApp links use the international number', () {
      expect(DirectoryEntry.whatsappDigits('012-345 6789'), '60123456789');
      expect(DirectoryEntry.whatsappDigits('+60 12-345 6789'), '60123456789');
    });

    testWidgets('a text-only service gets Message, not Call', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DirectoryScreen(library: _messagingLibrary()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Message Text service'), findsOneWidget);
      expect(find.bySemanticsLabel('Call Text service'), findsNothing);
      expect(find.text('Hours: 9 am to 5 pm'), findsOneWidget);
      expect(find.text('Source: example.org.my'), findsOneWidget);
      expect(find.textContaining('[add official source]'), findsNothing);
      // The phone line keeps its Call button.
      expect(find.bySemanticsLabel('Call Phone line'), findsOneWidget);
    });
  });

  testWidgets('Care help lines show the hours from the file', (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              for (final group in HelpLines.groupsFrom(_realLibrary()))
                HelplineGroupSection(group: group),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Hours: 9 am to 5 pm'), findsOneWidget); // WAO hotline
    expect(find.text('Hours: 24 hours a day, every day'), findsOneWidget);
    expect(find.text('Hours: 24 hours'), findsOneWidget); // TINA
  });

  testWidgets('Directory: only the file entries, with hours and sources', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final library = _realLibrary();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DirectoryScreen(library: library),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (final e in library.directory) {
      expect(find.text(e.name), findsOneWidget);
      if (e.number != null) expect(find.text(e.number!), findsOneWidget);
    }
    // Only 999 is still waiting for an official source.
    expect(find.text('Last checked: not yet confirmed'), findsOneWidget);
    expect(find.textContaining('[add official source]'), findsNothing);
    // Checked entries show their hours and source; 999 (unchecked) does not.
    expect(find.text('Hours: 9 am to 5 pm'), findsOneWidget);
    expect(find.text('Source: https://befrienders.org.my/'), findsOneWidget);
    expect(find.textContaining('Hours:'), findsNWidgets(4));
    // TINA: Message, not Call.
    expect(
      find.bySemanticsLabel('Message WAO TINA (SMS or WhatsApp)'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Call WAO TINA (SMS or WhatsApp)'),
      findsNothing,
    );
  });
}

/// A text-only service (like TINA) and a phone line with a placeholder
/// source.
ContentLibrary _messagingLibrary() => ContentLibrary.parse(
  guidesJson: jsonEncode({'guides': []}),
  directoryJson: jsonEncode({
    'entries': [
      {
        'id': 'text-only',
        'name': 'Text service',
        'helps': 'Support by message',
        'sms': '012-345 6789',
        'whatsapp': '012-345 6789',
        'verified': true,
        'hours': '9 am to 5 pm',
        'source': 'example.org.my',
        'lastChecked': '2026-11-01',
      },
      {
        'id': 'placeholder',
        'name': 'Phone line',
        'helps': 'Listening',
        'number': '15999',
        'verified': false,
        'source': '[add official source]',
      },
    ],
  }),
);
