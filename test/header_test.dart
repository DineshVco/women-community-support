import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/care/care_screen.dart';
import 'package:women_community_support/presentation/widgets/hero_card.dart';
import 'package:women_community_support/presentation/widgets/ios.dart';
import 'package:women_community_support/presentation/widgets/looma_header.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

/// A phone with a 47 pt status bar.
void _phone(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47);
  addTearDown(tester.view.reset);
}

Widget _app(
  Widget home, {
  double textScale = 1,
  bool reduceMotion = false,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
  home: home,
);

Widget _tab(String title) => LargeTitleScaffold(
  title: title,
  trailing: const QuickExitButton(),
  slivers: [
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => SizedBox(height: 80, child: Text('Row $i')),
        childCount: 40,
      ),
    ),
  ],
);

Finder get _quickExit => find.byType(QuickExitButton);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Real fonts, so widths match a phone (the test font draws every letter
  // as a full square).
  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(rootBundle.load('assets/fonts/$f'));
      }
      await loader.load();
    }

    await load('Newsreader', ['Newsreader-Regular.ttf']);
    await load('Figtree', ['Figtree-Regular.ttf', 'Figtree-Medium.ttf']);
  });

  testWidgets('title and Quick exit share one row, centred together', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_tab('Discuss')));
    final title = tester.getRect(find.text('Discuss'));
    final exit = tester.getRect(_quickExit);
    expect(find.text('Quick exit'), findsOneWidget);
    expect(title.right, lessThan(exit.left)); // title left, button right
    expect((title.center.dy - exit.center.dy).abs(), lessThan(2));
    // 4 px under the status bar.
    expect(title.top, lessThan(47 + LoomaHeader.topGap + 8));
  });

  testWidgets('Quick exit: a 32 px pill with a tap area of at least 44', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_tab('Care')));
    final pill = tester.getSize(
      find.descendant(of: _quickExit, matching: find.byType(Material)).first,
    );
    expect(pill.height, QuickExitButton.height);
    // The tappable area (Material pads it to 48).
    final hit = tester.getSize(_quickExit);
    expect(hit.height, greaterThanOrEqualTo(44));
    expect(hit.width, greaterThanOrEqualTo(44));
    // A tap 1 px inside the top of the hit area (outside the 32 px pill)
    // still works: the first tap shows the Quick exit introduction.
    final rect = tester.getRect(_quickExit);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
    await tester.pumpAndSettle();
    expect(find.text('Try it'), findsOneWidget);
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (390.0, 2.0)]) {
    testWidgets('${width.round()} px wide, text ${scale}x: no overflow, '
        'no overlap, Quick exit still there', (tester) async {
      _phone(tester, width: width);
      for (final title in ['Discuss', 'Care', 'Me']) {
        await tester.pumpWidget(_app(_tab(title), textScale: scale));
        expect(tester.takeException(), isNull, reason: title);
        expect(_quickExit, findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Quick exit')), findsWidgets);
        final t = tester.getRect(find.text(title));
        final q = tester.getRect(_quickExit);
        expect(t.right, lessThanOrEqualTo(q.left), reason: title);
        expect(q.right, lessThanOrEqualTo(width));
        expect(tester.getSize(_quickExit).height, greaterThanOrEqualTo(44));
      }
    });
  }

  testWidgets('scrolled: the title shrinks into a blurred bar', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_tab('Discuss')));
    final big = tester.getSize(find.text('Discuss')).height;
    expect(find.byType(BackdropFilter), findsNothing); // clear at the top

    await tester.drag(find.text('Row 2'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('Discuss')).height, lessThan(big));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_quickExit, findsOneWidget); // still on the same row
  });

  testWidgets('Reduce motion: large or small, never in between', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_tab('Discuss'), reduceMotion: true));
    final big = tester.getSize(find.text('Discuss')).height;
    // A small scroll (less than half the shrink) keeps it large.
    await tester.drag(find.text('Row 2'), const Offset(0, -10));
    await tester.pump();
    expect(tester.getSize(find.text('Discuss')).height, big);
    await tester.drag(find.text('Row 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    final small = tester.getSize(find.text('Discuss')).height;
    expect(small, lessThan(big));
    // And nothing keeps animating.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Care: the first card starts higher than before', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const CareScreen()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final top = tester.getRect(find.byType(HeroCard)).top;
    // Before this change the hero card started 151 px down on this phone
    // (Quick exit on its own row above the title).
    expect(top, lessThan(151 - 40));
    // Status bar + 4 + the title row + 8 px.
    expect(top, lessThanOrEqualTo(47 + 4 + 48 + 8 + 1));
  });
}
