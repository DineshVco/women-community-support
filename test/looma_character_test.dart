import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/looma_character.dart';

Widget _app({required bool reduceMotion, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Scaffold(body: Center(child: LoomaCharacter(height: 200))),
    ),
  );
}

void main() {
  testWidgets('builds all three picture layers at the right size', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Image), findsNWidgets(3));
    final size = tester.getSize(find.byType(LoomaCharacter));
    expect(size.height, 200);
    expect(size.width, closeTo(200 * 900 / 959, 0.01));
    expect(
      find.bySemanticsLabel(RegExp('smiling woman holding a mug')),
      findsOneWidget,
    );
  });

  testWidgets('keeps animating when motion is allowed', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('does not animate when reduce motion is on', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.pump();

    // No animation is running, so no further frames are requested.
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(
      find.byType(CustomPaint).evaluate().where((e) {
        final w = e.widget as CustomPaint;
        return w.painter != null &&
            w.painter.runtimeType.toString() == '_SteamPainter';
      }),
      isEmpty,
    );
  });

  testWidgets('lays out in dark mode at every size the app uses', (
    tester,
  ) async {
    for (final height in [130.0, 150.0, 170.0, 190.0, 220.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: LoomaCharacter(height: height))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'height $height');
    }
  });

  testWidgets('sits on a white card in dark mode', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true, theme: AppTheme.dark));
    await tester.pump();

    final whiteCards = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(LoomaCharacter),
            matching: find.byType(Container),
          ),
        )
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == Colors.white,
        );
    expect(whiteCards, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
