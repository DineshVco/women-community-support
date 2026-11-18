import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/looma_button.dart';
import 'package:women_community_support/presentation/widgets/press_scale.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a press calls the action and shrinks while held', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(LoomaButton.primary(label: 'Continue', onPressed: () => taps++)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final scale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byType(PressScale),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(scale.scale, 0.97);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));
    expect(taps, 1);
  });

  testWidgets('success shows a tick instead of the label and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        LoomaButton.primary(
          label: 'Continue',
          success: true,
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.byType(LoomaButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });
}
