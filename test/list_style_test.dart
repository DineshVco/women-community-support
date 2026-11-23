import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_icons.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/care/care_screen.dart';
import 'package:women_community_support/presentation/widgets/ios.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: ListView(children: [child])),
);

/// The circle behind a row's icon.
Color _circle(WidgetTester tester, IconData icon) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
        .first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('$name: a section is one card like the feed', (tester) async {
      await tester.pumpWidget(
        _app(
          const GroupedSection(
            header: 'Tools',
            children: [
              GroupedRow(icon: AppIcons.breathe, title: 'Breathe'),
              GroupedRow(icon: AppIcons.ground, title: 'Ground yourself'),
            ],
          ),
          theme: theme,
        ),
      );
      final card = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GroupedSection),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(card.borderRadius, BorderRadius.circular(20));
      expect((card.border! as Border).top.width, 1);
      expect(
        card.boxShadow ?? const [],
        theme.brightness == Brightness.light ? hasLength(2) : isEmpty,
      );
      expect(find.text('TOOLS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('row icons sit in a soft circle', (tester) async {
    await tester.pumpWidget(
      _app(
        const GroupedSection(
          children: [GroupedRow(icon: AppIcons.lock, title: 'App lock')],
        ),
      ),
    );
    expect(_circle(tester, AppIcons.lock), AppPalette.light.softFill);
  });

  testWidgets('"Coming soon": readable text and a tag, not greyed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const GroupedSection(
          children: [
            GroupedRow(
              icon: AppIcons.envelope,
              title: 'My requests',
              trailing: ComingSoonTag(),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Coming soon'), findsOneWidget);
    final title = tester.widget<Text>(find.text('My requests'));
    expect(title.style!.color, AppPalette.light.text);
    // No chevron: it does not open anything yet.
    expect(find.byType(CupertinoListTileChevron), findsNothing);
  });

  testWidgets('Care: tools have soft coloured icon circles', (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const CareScreen()),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final colours = {
      for (final icon in [
        AppIcons.breathe,
        AppIcons.ground,
        AppIcons.mood,
        AppIcons.book,
      ])
        _circle(tester, icon),
    };
    // Sage, sand, blush and lavender: four different soft colours.
    expect(colours, hasLength(4));
    expect(colours, isNot(contains(AppPalette.light.softFill)));
  });
}
