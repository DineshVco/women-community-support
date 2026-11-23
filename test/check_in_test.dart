import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/mood.dart';
import 'package:women_community_support/presentation/screens/care/care_screen.dart';
import 'package:women_community_support/presentation/widgets/check_in_row.dart';

final _today = DateTime(2026, 11, 23, 9, 30);

Widget _app(
  Widget child, {
  ThemeData? theme,
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [child]),
    ),
  ),
);

/// Lets the encrypted store finish (it is asynchronous).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tap saves today, encrypted, and it reloads', (tester) async {
    final secure = MemorySecureStore();
    final steps = <CheckInStep>[];
    await tester.pumpWidget(
      _app(
        CheckInRow(store: MoodStore(secure), today: _today, onStep: steps.add),
      ),
    );
    await _settle(tester);
    expect(find.text(CheckInRow.title), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Low'));
    await _settle(tester);

    // A gentle line and one next step.
    expect(find.text('Today: Low'), findsOneWidget);
    expect(find.text(CheckInRow.replyFor(Mood.low)), findsOneWidget);
    await tester.tap(find.text('Breathe slowly with the cat'));
    expect(steps, [CheckInStep.breathe]);

    // Stored only encrypted: nothing readable in the raw values.
    final raw = secure.values.values.join(' ');
    expect(raw, isNot(contains('low')));
    expect(raw, isNot(contains('2026-11-23')));

    // A fresh store on the same phone reads it back.
    final entries = (await tester.runAsync(() => MoodStore(secure).load()))!;
    expect(entries[MoodEntry.keyFor(_today)]?.mood, Mood.low);
  });

  testWidgets('already answered: her answer and a small "Change"', (
    tester,
  ) async {
    final secure = MemorySecureStore();
    final store = MoodStore(secure);
    await tester.runAsync(
      () => store.save(
        MoodEntry(day: DateTime(2026, 11, 23), mood: Mood.good, note: 'Walk'),
      ),
    );
    await tester.pumpWidget(
      _app(CheckInRow(store: store, today: _today, onStep: (_) {})),
    );
    await _settle(tester);
    expect(find.text('Today: Good'), findsOneWidget);
    expect(find.bySemanticsLabel('Great'), findsNothing); // no faces yet

    await tester.tap(find.text('Change'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Great'));
    await _settle(tester);
    expect(find.text('Today: Great'), findsOneWidget);

    // Same entry replaced, and her note kept.
    final entries = (await tester.runAsync(() => store.load()))!;
    expect(entries, hasLength(1));
    expect(entries.values.single.mood, Mood.great);
    expect(entries.values.single.note, 'Walk');
  });

  test('each face has a reply and one next step; hard days calm first', () {
    for (final mood in Mood.values) {
      expect(CheckInRow.replyFor(mood), isNotEmpty);
    }
    expect(CheckInRow.stepFor(Mood.low).$1, CheckInStep.breathe);
    expect(CheckInRow.stepFor(Mood.rough).$1, CheckInStep.breathe);
    expect(CheckInRow.order, hasLength(5));
  });

  testWidgets('without the private store the row is not shown', (tester) async {
    await tester.pumpWidget(_app(CheckInRow(onStep: (_) {})));
    await tester.pump();
    expect(find.text(CheckInRow.title), findsNothing);
  });

  for (final (name, theme, scale) in [
    ('320 px, text 2x', AppTheme.light, 2.0),
    ('320 px, dark mode', AppTheme.dark, 1.0),
  ]) {
    testWidgets('$name: no overflow, before and after answering', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          CheckInRow(
            store: MoodStore(MemorySecureStore()),
            today: _today,
            onStep: (_) {},
          ),
          theme: theme,
          textScale: scale,
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('Okay'));
      await _settle(tester);
      expect(find.text('Today: Okay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Reduce motion: the answer just appears', (tester) async {
    await tester.pumpWidget(
      _app(
        CheckInRow(
          store: MoodStore(MemorySecureStore()),
          today: _today,
          onStep: (_) {},
        ),
        reduceMotion: true,
      ),
    );
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Good'));
    await tester.pump();
    expect(find.text('Today: Good'), findsOneWidget);
    expect(find.bySemanticsLabel('Great'), findsNothing); // no cross-fade
  });

  testWidgets('on Care: under the Call 999 card, which stays first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<MoodStore>.value(
        value: MoodStore(MemorySecureStore()),
        child: MaterialApp(theme: AppTheme.light, home: const CareScreen()),
      ),
    );
    await _settle(tester);
    final call = tester.getRect(find.text('Call 999'));
    final row = tester.getRect(find.text(CheckInRow.title));
    final tools = tester.getRect(find.text('TOOLS'));
    expect(call.top, lessThan(row.top));
    expect(row.top, lessThan(tools.top));
  });
}
