import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/cat_avatar.dart';
import 'package:women_community_support/presentation/widgets/living_cat.dart';
import 'package:women_community_support/presentation/widgets/posted_confirmation.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
  home: Scaffold(body: Center(child: child)),
);

CatEyes? _eyes(WidgetTester tester) =>
    tester.widget<CatAvatar>(find.byKey(const ValueKey('living-cat'))).eyes;

double _angle(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find.byKey(const ValueKey('living-cat-pose')),
  );
  return t.transform.getRotation().entry(1, 0).abs();
}

void main() {
  testWidgets('blinks now and then, eyes open the rest of the time', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const LivingCat()));
    var open = 0;
    var closed = 0;
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      _eyes(tester) == CatEyes.closed ? closed++ : open++;
    }
    expect(closed, greaterThan(0)); // it blinked
    expect(open, greaterThan(closed * 5)); // mostly open
  });

  testWidgets('a gentle bob of 2 px at most', (tester) async {
    await tester.pumpWidget(_app(const LivingCat()));
    final start =
        tester.getTopLeft(find.byKey(const ValueKey('living-cat'))).dy;
    var furthest = 0.0;
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final y = tester.getTopLeft(find.byKey(const ValueKey('living-cat'))).dy;
      furthest = (y - start).abs() > furthest ? (y - start).abs() : furthest;
    }
    expect(furthest, greaterThan(0.5)); // it moves
    expect(furthest, lessThanOrEqualTo(LivingCat.bobHeight + 0.01));
  });

  testWidgets('sleepy eyes at night, and no blinking', (tester) async {
    await tester.pumpWidget(_app(const LivingCat(night: true)));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(_eyes(tester), CatEyes.closed);
    }
  });

  testWidgets('waves when she posts, then settles', (tester) async {
    await tester.pumpWidget(_app(const LivingCat()));
    LivingCat.cue(CatCue.wave);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_angle(tester), greaterThan(0.01));
    await tester.pump(LivingCat.gestureLength);
    expect(_angle(tester), lessThan(0.001));
  });

  testWidgets('Reduce motion: no blink, no bob, no wave', (tester) async {
    await tester.pumpWidget(_app(const LivingCat(), reduceMotion: true));
    final start = tester.getTopLeft(find.byKey(const ValueKey('living-cat')));
    LivingCat.cue(CatCue.wave);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(_eyes(tester), CatEyes.open);
      expect(_angle(tester), lessThan(0.001));
    }
    expect(tester.getTopLeft(find.byKey(const ValueKey('living-cat'))), start);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Reduce motion at night: simply closed eyes', (tester) async {
    await tester.pumpWidget(
      _app(const LivingCat(night: true), reduceMotion: true),
    );
    expect(_eyes(tester), CatEyes.closed);
  });

  group('"Me too": a tiny cat nods', () {
    testWidgets('appears, nods, and is gone after about a second', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const CatNodFlash(trigger: 0)));
      expect(find.byKey(const ValueKey('nod-cat')), findsNothing);
      await tester.pumpWidget(_app(const CatNodFlash(trigger: 1)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('nod-cat')), findsOneWidget);
      await tester.pump(CatNodFlash.length);
      expect(find.byKey(const ValueKey('nod-cat')), findsNothing);
    });

    testWidgets('Reduce motion: no cat', (tester) async {
      await tester.pumpWidget(
        _app(const CatNodFlash(trigger: 0), reduceMotion: true),
      );
      await tester.pumpWidget(
        _app(const CatNodFlash(trigger: 1), reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('nod-cat')), findsNothing);
    });
  });

  group('after posting: a calm confirmation', () {
    for (final reduce in [false, true]) {
      testWidgets('the cat nods with a soft check, gone in about 1.2 s '
          '${reduce ? '(Reduce motion)' : ''}', (tester) async {
        await tester.pumpWidget(
          _app(
            Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () =>
                            showPostedConfirmation(context, alias: 'Quiet Fox'),
                    child: const Text('post'),
                  ),
            ),
            reduceMotion: reduce,
          ),
        );
        await tester.tap(find.text('post'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Posted as Quiet Fox'), findsOneWidget);
        expect(find.byKey(const ValueKey('posted-check')), findsOneWidget);
        expect(find.byType(LivingCat), findsOneWidget);
        // Not a dialog: the page behind can still be tapped.
        expect(find.byType(Dialog), findsNothing);
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Posted as Quiet Fox'), findsNothing);
      });
    }
  });
}
