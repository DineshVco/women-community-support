import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_icons.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/app_shell.dart';
import 'package:women_community_support/presentation/widgets/cat_avatar.dart';

Widget _bar({
  int index = 0,
  ThemeData? theme,
  bool reduceMotion = false,
  double textScale = 1,
  ValueChanged<int>? onTap,
  String? meAvatarId,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Builder(
      builder:
          (context) => Scaffold(
            bottomNavigationBar: AppShell.tabBar(
              context,
              index: index,
              onTap: onTap ?? (_) {},
              meAvatarId: meAvatarId,
            ),
          ),
    ),
  ),
);

/// The blush pill of a tab.
Color _pillColour(WidgetTester tester, String tab) {
  final pill = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('tab-pill-$tab')),
  );
  return (pill.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('only the active tab shows its name, in the blush pill', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(index: 1));
    await tester.pumpAndSettle();
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('Discuss'), findsNothing);
    expect(find.text('Me'), findsNothing); // the avatar only
    expect(find.byIcon(AppIcons.careActive), findsOneWidget); // filled
    expect(find.byIcon(AppIcons.discuss), findsOneWidget); // outline
    expect(_pillColour(tester, 'Care').a, greaterThan(0));
    expect(_pillColour(tester, 'Discuss').a, 0);
    // The name sits next to the icon, on the same line.
    final icon = tester.getRect(find.byIcon(AppIcons.careActive));
    final name = tester.getRect(find.text('Care'));
    expect(name.left, greaterThan(icon.right));
    expect((name.center.dy - icon.center.dy).abs(), lessThan(3));
  });

  testWidgets('screen readers hear every tab, selected or not', (tester) async {
    await tester.pumpWidget(_bar(index: 0));
    await tester.pumpAndSettle();
    for (final tab in ['Discuss', 'Care', 'Me']) {
      expect(find.bySemanticsLabel(tab), findsOneWidget, reason: tab);
    }
    final me = tester.getSemantics(find.bySemanticsLabel('Me'));
    expect(me.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(me.hasFlag(SemanticsFlag.isButton), isTrue);
    final discuss = tester.getSemantics(find.bySemanticsLabel('Discuss'));
    expect(discuss.hasFlag(SemanticsFlag.isSelected), isTrue);
  });

  testWidgets('every tab is a tap area of at least 48 px', (tester) async {
    int? tapped;
    await tester.pumpWidget(_bar(onTap: (i) => tapped = i));
    for (final tab in ['Discuss', 'Care', 'Me']) {
      final size = tester.getSize(find.byKey(ValueKey('tab-$tab')));
      expect(size.height, greaterThanOrEqualTo(48), reason: tab);
      expect(size.width, greaterThanOrEqualTo(48), reason: tab);
    }
    await tester.tap(find.byKey(const ValueKey('tab-Me')));
    expect(tapped, 2);
  });

  testWidgets('translucent, so it blurs what scrolls under it', (tester) async {
    await tester.pumpWidget(_bar());
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('the pill widens smoothly as the name appears', (tester) async {
    await tester.pumpWidget(_bar(index: 0));
    await tester.pumpAndSettle();
    final narrow = tester.getSize(find.byKey(const ValueKey('tab-pill-Care')));
    await tester.pumpWidget(_bar(index: 1));
    await tester.pump(const Duration(milliseconds: 60));
    final middle = tester.getSize(find.byKey(const ValueKey('tab-pill-Care')));
    await tester.pumpAndSettle();
    final wide = tester.getSize(find.byKey(const ValueKey('tab-pill-Care')));
    expect(middle.width, greaterThan(narrow.width));
    expect(middle.width, lessThan(wide.width));
  });

  testWidgets('Reduce motion: the pill and name just switch', (tester) async {
    await tester.pumpWidget(_bar(reduceMotion: true));
    await tester.pumpWidget(_bar(index: 1, reduceMotion: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Care'), findsOneWidget);
    expect(_pillColour(tester, 'Care').a, greaterThan(0));
  });

  for (final (name, theme, scale) in [
    ('320 px, 2x text', AppTheme.light, 2.0),
    ('320 px, dark mode', AppTheme.dark, 1.0),
  ]) {
    for (final index in [0, 1, 2]) {
      testWidgets('$name, tab $index active: no overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _bar(index: index, theme: theme, textScale: scale),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(['Discuss', 'Care', 'Me'][index]), findsOneWidget);
      });
    }
  }

  group('Me tab: her avatar', () {
    String shownId(WidgetTester tester) =>
        tester.widget<CatAvatar>(find.byType(CatAvatar)).id;

    testWidgets('no avatar yet: the cat, and no "Me" text', (tester) async {
      await tester.pumpWidget(_bar());
      expect(shownId(tester), CatAvatars.fallback);
      expect(find.text('Me'), findsNothing);
    });

    testWidgets('with an avatar: hers, read out as "Me", last tab', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(meAvatarId: 'cat_07'));
      expect(shownId(tester), 'cat_07');
      final xs = [
        for (final t in ['Discuss', 'Care', 'Me'])
          tester.getCenter(find.byKey(ValueKey('tab-$t'))).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort())); // Me is last
      expect(find.bySemanticsLabel(RegExp('Cat avatar')), findsNothing);
    });

    testWidgets('active: avatar and "Me" in the pill, blush ring', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(index: 2, meAvatarId: 'cat_03'));
      await tester.pumpAndSettle();
      expect(find.text('Me'), findsOneWidget);
      expect(shownId(tester), 'cat_03');
      final ring = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('me-tab-ring')),
      );
      final border = (ring.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, AppPalette.light.blush);
    });

    testWidgets('an unknown id falls back to the cat', (tester) async {
      await tester.pumpWidget(_bar(meAvatarId: 'not_a_cat'));
      expect(shownId(tester), CatAvatars.fallback);
    });
  });
}
