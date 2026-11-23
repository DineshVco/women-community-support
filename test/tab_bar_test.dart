import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_icons.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/app_shell.dart';

Widget _bar({
  int index = 0,
  ThemeData? theme,
  bool reduceMotion = false,
  double textScale = 1,
  ValueChanged<int>? onTap,
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
            ),
          ),
    ),
  ),
);

BoxDecoration _pill(WidgetTester tester, IconData icon) {
  final tab = find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(TabIcon),
  );
  final box = tester.widget<Container>(
    find.descendant(of: tab, matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

void main() {
  testWidgets('the active tab: filled icon on a blush pill', (tester) async {
    await tester.pumpWidget(_bar(index: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.careActive), findsOneWidget);
    expect(find.byIcon(AppIcons.discuss), findsOneWidget); // outline
    expect(find.byIcon(AppIcons.me), findsOneWidget);
    expect(_pill(tester, AppIcons.careActive).color!.a, greaterThan(0));
    expect(_pill(tester, AppIcons.discuss).color!.a, 0);
  });

  testWidgets('translucent, so it blurs what scrolls under it', (tester) async {
    await tester.pumpWidget(_bar());
    final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(bar.backgroundColor!.a, lessThan(1));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('tapping a tab reports it', (tester) async {
    int? tapped;
    await tester.pumpWidget(_bar(onTap: (i) => tapped = i));
    await tester.tap(find.text('Me'));
    expect(tapped, 2);
  });

  for (final (name, theme, scale) in [
    ('dark mode', AppTheme.dark, 1.0),
    ('large text', AppTheme.light, 2.0),
  ]) {
    testWidgets('fits in $name', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_bar(theme: theme, textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Reduce motion: the pill just appears', (tester) async {
    await tester.pumpWidget(_bar(reduceMotion: true));
    await tester.pumpWidget(_bar(index: 2, reduceMotion: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_pill(tester, AppIcons.meActive).color!.a, greaterThan(0));
  });
}
