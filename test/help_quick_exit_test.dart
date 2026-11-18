import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/constants/helplines.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
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

Widget _helpApp({ThemeData? theme}) =>
    MaterialApp(theme: theme ?? AppTheme.light, home: const HelpScreen());

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

    testWidgets('lists every helpline with its number, Call and Copy', (
      tester,
    ) async {
      _tallScreen(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      for (final line in Helplines.support) {
        expect(find.text(line.name), findsOneWidget);
        expect(find.text(line.number), findsOneWidget);
      }
      expect(find.text('Call'), findsNWidgets(Helplines.support.length));
      expect(find.text('Copy'), findsNWidgets(Helplines.support.length));
      // No date has been confirmed yet, and the page says so honestly.
      expect(
        find.text('Last checked: not yet confirmed'),
        findsNWidgets(Helplines.groups.length),
      );
    });

    testWidgets('Copy puts the number on the clipboard and says "Copied"', (
      tester,
    ) async {
      _tallScreen(tester);
      final copied = _captureClipboard(tester);
      await tester.pumpWidget(_helpApp());
      await _wait(tester);

      await tester.tap(
        find.bySemanticsLabel('Copy ${Helplines.wao.name} number'),
      );
      await tester.pump();

      expect(copied, [Helplines.wao.number]);
      expect(find.text('Copied ${Helplines.wao.number}'), findsOneWidget);
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

  test('helpline numbers are the ones in the data, unchanged', () {
    // Guards against numbers being edited by accident. Change only after
    // checking the organisation's official website.
    expect(Helplines.emergency.number, '999');
    expect(Helplines.befriendersKL.number, '03-7627 2929');
    expect(Helplines.talianKasih.number, '15999');
    expect(Helplines.wao.number, '03-3000 8858');
    expect(Helplines.groups.map((g) => g.title), [
      'Talk to someone now',
      'Women and family support',
    ]);
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
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
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
