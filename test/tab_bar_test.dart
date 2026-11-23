import 'dart:math' as math;
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
  testWidgets('every tab shows its name under the icon; active in the pill', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(index: 1));
    await tester.pumpAndSettle();
    for (final tab in ['Discuss', 'Care', 'Me']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
    expect(find.byIcon(AppIcons.careActive), findsOneWidget); // filled
    expect(find.byIcon(AppIcons.discuss), findsOneWidget); // outline
    expect(_pillColour(tester, 'Care'), AppPalette.light.tabPill);
    expect(_pillColour(tester, 'Discuss').a, 0);
    // The name sits under its icon, and the pill wraps both.
    final icon = tester.getRect(find.byIcon(AppIcons.careActive));
    final name = tester.getRect(find.text('Care'));
    final pill = tester.getRect(find.byKey(const ValueKey('tab-pill-Care')));
    expect(name.top, greaterThanOrEqualTo(icon.bottom));
    expect((name.center.dx - icon.center.dx).abs(), lessThan(2));
    expect(pill.contains(icon.center) && pill.contains(name.center), isTrue);
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

  testWidgets('the pill fades in smoothly', (tester) async {
    await tester.pumpWidget(_bar(index: 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_bar(index: 1));
    await tester.pump(const Duration(milliseconds: 60));
    final middle =
        tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('tab-pill-Care')),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration;
    await tester.pumpAndSettle();
    final alpha = (middle! as BoxDecoration).color!.a;
    expect(alpha, greaterThan(0));
    expect(alpha, lessThan(1));
    expect(_pillColour(tester, 'Care'), AppPalette.light.tabPill);
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

    testWidgets('no avatar yet: the cat, with "Me" under it', (tester) async {
      await tester.pumpWidget(_bar());
      expect(shownId(tester), CatAvatars.fallback);
      expect(find.text('Me'), findsOneWidget);
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

  group('inactive icons: darker warm grey, 24 px', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final (name, p) in [
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name: at least 3:1 on the see-through bar', () {
        // The bar is the page colour at 82% over whatever scrolls under it.
        for (final under in [
          p.background,
          p.surface,
          Colors.white,
          Colors.black,
        ]) {
          final bar = Color.alphaBlend(
            p.background.withValues(alpha: 0.82),
            under,
          );
          expect(contrast(p.tabInactive, bar), greaterThanOrEqualTo(3));
        }
        // Darker than the old grey on light, lighter on dark.
        expect(
          contrast(p.tabInactive, p.background),
          greaterThan(contrast(p.textSecondary, p.background)),
        );
      });
    }

    testWidgets('used for inactive tabs, at 24 px', (tester) async {
      await tester.pumpWidget(_bar(index: 0));
      final icon = find.byIcon(AppIcons.care);
      final theme = IconTheme.of(tester.element(icon));
      expect(theme.color, AppPalette.light.tabInactive);
      expect(theme.size, 24);
    });
  });
}
