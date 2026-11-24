import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';
import 'package:women_community_support/presentation/widgets/floating_illustration.dart';

Widget _app({bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder:
        (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
        ),
  ),
);

/// Lets entrances and page animations finish. Not pumpAndSettle: the
/// pictures float forever when motion is allowed.
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _cat(String asset) => find.byWidgetPredicate(
  (w) => w is FloatingIllustration && w.asset == asset,
);

/// The drawing itself (the float moves it inside the widget).
Finder _image(String asset) =>
    find.descendant(of: _cat(asset), matching: find.byType(Image));

Future<void> _swipeLeft(WidgetTester tester) async {
  await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
  await _wait(tester);
}

/// How visible the illustration is (its entrance fade).
double _opacityOf(WidgetTester tester, Finder cat) {
  final opacities = tester.widgetList<Opacity>(
    find.descendant(of: cat, matching: find.byType(Opacity)),
  );
  return opacities.first.opacity;
}

void main() {
  testWidgets('4 pages: the girl, then a cat on each idea page', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _wait(tester);

    expect(find.text('Welcome to Looma'), findsOneWidget);
    expect(find.byType(FloatingIllustration), findsNothing);

    await _swipeLeft(tester);
    expect(find.text('Share without your name'), findsOneWidget);
    expect(_cat(LoomaCats.share), findsOneWidget);
    expect(_opacityOf(tester, _cat(LoomaCats.share)), 1);
    expect(find.bySemanticsLabel('Page 2 of 4'), findsOneWidget);

    await _swipeLeft(tester);
    expect(find.text('Browse by category'), findsOneWidget);
    expect(_cat(LoomaCats.browse), findsOneWidget);
    expect(find.bySemanticsLabel('Page 3 of 4'), findsOneWidget);

    await _swipeLeft(tester);
    expect(find.text('Report what feels wrong'), findsOneWidget);
    expect(_cat(LoomaCats.safe), findsOneWidget);
    expect(find.bySemanticsLabel('Page 4 of 4'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Skip jumps from page 2 to page 4', (tester) async {
    await tester.pumpWidget(_app());
    await _wait(tester);
    await _swipeLeft(tester);

    await tester.tap(find.text('Skip'));
    await _wait(tester);

    expect(find.text('Report what feels wrong'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 4 of 4'), findsOneWidget);
  });

  testWidgets('the cat floats when motion is allowed', (tester) async {
    await tester.pumpWidget(_app());
    await _wait(tester);
    await _swipeLeft(tester);

    final cat = _image(LoomaCats.share);
    final y1 = tester.getTopLeft(cat).dy;
    await tester.pump(const Duration(milliseconds: 900));
    final y2 = tester.getTopLeft(cat).dy;
    expect(y1, isNot(y2));
  });

  testWidgets('no animation when disableAnimations is true', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    // Settles: nothing loops, so this returns instead of timing out.
    await tester.pumpAndSettle();
    expect(find.text('Share without your name'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Shown at once, and not moving.
    final cat = _cat(LoomaCats.share);
    expect(_opacityOf(tester, cat), 1);
    final image = _image(LoomaCats.share);
    final y1 = tester.getTopLeft(image).dy;
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(image).dy, y1);

    // Skip jumps straight to the last page.
    await tester.tap(find.text('Skip'));
    // One frame to jump, one for the page dots to redraw; then nothing.
    await tester.pump();
    await tester.pump();
    expect(find.text('Report what feels wrong'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
