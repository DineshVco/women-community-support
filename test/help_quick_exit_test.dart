import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/theme/app_icons.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/data/help_lines.dart';
import 'package:women_community_support/presentation/screens/decoy_screen.dart';
import 'package:women_community_support/presentation/screens/help_screen.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

/// A tall phone so the whole page is built (ListView is lazy).
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets the 60 ms staggered fade-ins finish (the cat floats forever, so
/// pumpAndSettle would never return).
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Records what the app copies to the clipboard.
List<String> _captureClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// The real content/directory.json, as the app loads it at start-up.
final ContentLibrary _library = ContentLibrary.parse(
  guidesJson: File('content/guides.json').readAsStringSync(),
  directoryJson: File('content/directory.json').readAsStringSync(),
);

/// Every help line on the page (all but 999, which is the danger card).
List<DirectoryEntry> get _lines => [
  for (final g in HelpLines.groupsFrom(_library)) ...g.entries,
];

Widget _helpApp({ThemeData? theme}) => ContentScope(
  library: _library,
  child: MaterialApp(theme: theme ?? AppTheme.light, home: const HelpScreen()),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ───────────────────────── Get help ─────────────────────────

  group('Get help', () {
    testWidgets('shows every section in order', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      expect(find.text('You are not alone'), findsOneWidget);
      expect(find.text(HelpScreen.headerLine), findsOneWidget);
      expect(find.text('In danger right now?'), findsOneWidget);
      expect(find.text('Call 999'), findsOneWidget);
      expect(find.text('Talk to someone now'), findsOneWidget);
      expect(find.text('Women and family support'), findsOneWidget);
      expect(find.text('Safe ways to reach out'), findsOneWidget);
      expect(find.text('Worried someone can see your screen?'), findsOneWidget);
      expect(find.text('Practice Quick exit'), findsOneWidget);

      final top = tester.getTopLeft(find.text('You are not alone')).dy;
      final danger = tester.getTopLeft(find.text('In danger right now?')).dy;
      final talk = tester.getTopLeft(find.text('Talk to someone now')).dy;
      final safe = tester.getTopLeft(find.text('Safe ways to reach out')).dy;
      expect(top < danger && danger < talk && talk < safe, isTrue);
    });

    testWidgets('lists every help line from the directory file', (
      tester,
    ) async {
      _tallScreen(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      for (final line in _lines) {
        expect(find.text(line.name), findsOneWidget, reason: line.id);
        expect(
          find.bySemanticsLabel('Copy ${line.name} number'),
          findsOneWidget,
        );
      }
      final callable = _lines.where((l) => l.number != null).length;
      final messaging = _lines.where((l) => l.canMessage).length;
      expect(find.text('Call'), findsNWidgets(callable));
      expect(find.text('Message'), findsNWidgets(messaging));
      // Checked on 18 Nov 2026 for both groups.
      expect(find.textContaining('Last checked: '), findsNWidgets(2));
      expect(find.text('Last checked: not yet confirmed'), findsNothing);
    });

    testWidgets('TINA: Message (SMS or WhatsApp, her choice), no Call', (
      tester,
    ) async {
      _tallScreen(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      const tina = 'WAO TINA (SMS or WhatsApp)';
      expect(find.text(tina), findsOneWidget);
      expect(find.text('018-988 8058'), findsOneWidget);
      expect(find.text('Hours: 24 hours'), findsOneWidget);
      expect(find.bySemanticsLabel('Call $tina'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Message $tina'));
      await _wait(tester);
      expect(find.text('Text message (SMS)'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _wait(tester);
    });

    testWidgets('Copy puts the number on the clipboard and says "Copied"', (
      tester,
    ) async {
      _tallScreen(tester);
      final copied = _captureClipboard(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      const wao = "Women's Aid Organisation (WAO) hotline";
      await tester.tap(find.bySemanticsLabel('Copy $wao number'));
      await tester.pump();

      expect(copied, ['03-3000 8858']);
      expect(find.text('Copied 03-3000 8858'), findsOneWidget);
    });

    testWidgets('Call copies the number on a device that cannot call', (
      tester,
    ) async {
      _tallScreen(tester);
      final copied = _captureClipboard(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      await tester.tap(find.text('Call 999'));
      // The phone dialler is not there in tests: wait for that answer.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(copied, ['999']);
    });

    testWidgets('looks right in dark mode too', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_helpApp(theme: AppTheme.dark));
      await _wait(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Call 999'), findsOneWidget);
    });
  });

  test('help line groups come from the directory file', () {
    final groups = HelpLines.groupsFrom(_library);
    expect(groups.map((g) => g.title), [
      'Talk to someone now',
      'Women and family support',
    ]);
    expect(groups[0].entries.map((e) => e.id), [
      'befrienders-kl',
      'talian-kasih',
    ]);
    expect(groups[1].entries.map((e) => e.id), ['wao-hotline', 'wao-tina']);
    // 999 is the danger card, not a list row.
    expect(_lines.any((e) => e.id == 'emergency'), isFalse);
  });

  // ───────────────────────── Quick exit ─────────────────────────

  group('Quick exit', () {
    Widget app() => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(actions: const [QuickExitButton()]),
        body: const Text('Looma page'),
      ),
    );

    testWidgets('the button has an icon and the label "Quick exit"', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      expect(find.text('Quick exit'), findsOneWidget);
      expect(find.byIcon(AppIcons.eyeSlash), findsOneWidget);
    });

    testWidgets('first tap explains it once; "Got it" stays in Looma', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('Quick exit'));
      await tester.pumpAndSettle();

      expect(find.text(QuickExit.introText), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(QuickExit.introSeenKey), isTrue);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Looma page'), findsOneWidget);
      expect(find.byType(DecoyScreen), findsNothing);

      // From now on: a single tap, no questions.
      await tester.tap(find.text('Quick exit'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DecoyScreen), findsOneWidget);
      expect(find.text('Looma page'), findsNothing);
      expect(find.text(QuickExit.introText), findsNothing);
    });

    testWidgets('"Try it" exits straight away', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('Quick exit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try it'));
      await tester.pumpAndSettle();

      expect(find.byType(DecoyScreen), findsOneWidget);
      expect(find.text('Looma page'), findsNothing);
    });

    testWidgets('once seen, one tap hides Looma with no animation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({QuickExit.introSeenKey: true});
      await tester.pumpWidget(app());
      await tester.tap(find.text('Quick exit'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DecoyScreen), findsOneWidget);
      expect(find.text('Looma page'), findsNothing);
      // Nothing left to go "back" to.
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('practice from Get help, then press and hold to come back', (
      tester,
    ) async {
      _tallScreen(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      await tester.tap(find.text('Practice Quick exit'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DecoyScreen), findsOneWidget);
      expect(
        find.textContaining('Practice: press and hold anywhere for 1 second'),
        findsOneWidget,
      );

      // Hold for 1 second (a normal long press is too short).
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(DecoyScreen)),
      );
      await tester.pump(const Duration(seconds: 1));
      await finger.up();
      await tester.pump();
      await tester.pump();
      expect(find.byType(DecoyScreen), findsNothing);
      expect(find.text('You are not alone'), findsOneWidget);
    });
  });
  // The weather and calculator screens are tested in disguise_test.dart.
}
