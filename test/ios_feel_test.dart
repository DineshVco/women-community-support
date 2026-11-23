import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/presentation/providers/app_settings.dart';
import 'package:women_community_support/presentation/screens/help_screen.dart';
import 'package:women_community_support/presentation/widgets/adaptive.dart';
import 'package:women_community_support/presentation/widgets/ios.dart';
import 'package:women_community_support/presentation/widgets/post_actions.dart';
import 'package:women_community_support/presentation/widgets/post_card.dart';

Widget _app(Widget home, {ThemeData? theme, double textScale = 1}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _post = Post(
  id: 'p1',
  alias: 'Quiet Fox',
  categoryId: 'education',
  title: 'Scholarship tips?',
  content: 'Any advice for first-year applications?',
  timestamp: DateTime(2026, 11, 18),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('large title collapses into the bar while scrolling', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        LargeTitleScaffold(
          title: 'Discuss',
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SizedBox(height: 80, child: Text('Row $i')),
                childCount: 40,
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    final bigBefore = tester.getSize(find.text('Discuss').first).height;

    await tester.drag(find.text('Row 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    // The large title has scrolled away; a small title stays in the bar.
    final visible = find.text('Discuss').hitTestable();
    expect(visible, findsOneWidget);
    expect(tester.getSize(visible).height, lessThan(bigBefore));
  });

  testWidgets('pull to refresh uses the iOS spinner', (tester) async {
    _phone(tester);
    var refreshed = false;
    await tester.pumpWidget(
      _app(
        LargeTitleScaffold(
          title: 'Discuss',
          onRefresh: () async => refreshed = true,
          slivers: const [SliverToBoxAdapter(child: SizedBox(height: 900))],
        ),
      ),
    );
    // The iOS refresh control is in the list (it only draws while pulled).
    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(
      scroll.slivers.whereType<CupertinoSliverRefreshControl>(),
      hasLength(1),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(refreshed, isTrue);
  });

  testWidgets('filters are clean pills, not Material chips', (tester) async {
    var selected = 'All';
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder:
              (context, setState) => Scaffold(
                body: Row(
                  children: [
                    for (final label in ['All', 'Health'])
                      Pill(
                        label: label,
                        selected: selected == label,
                        onTap: () => setState(() => selected = label),
                      ),
                  ],
                ),
              ),
        ),
      ),
    );
    expect(find.byType(FilterChip), findsNothing);
    await tester.tap(find.text('Health'));
    await tester.pump();
    expect(selected, 'Health');
    expect(
      tester
          .getSemantics(find.text('Health'))
          .hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
  });

  testWidgets('grouped list: iOS switch row and chevron row', (tester) async {
    var on = false;
    var tapped = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder:
              (context, setState) => Scaffold(
                body: ListView(
                  children: [
                    GroupedSection(
                      header: 'Appearance',
                      children: [
                        GroupedSwitchRow(
                          title: 'Gentle mode',
                          value: on,
                          onChanged: (v) => setState(() => on = v),
                        ),
                        GroupedRow(
                          title: 'Weather city',
                          value: 'Kuala Lumpur',
                          onTap: () => tapped = true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
    expect(find.text('APPEARANCE'), findsOneWidget); // small caps header
    expect(find.byType(CupertinoListTileChevron), findsOneWidget);
    expect(find.text('Kuala Lumpur'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue);
    await tester.tap(find.text('Weather city'));
    expect(tapped, isTrue);
  });

  testWidgets('destructive confirm is an iOS alert with a red action', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Builder(
          builder:
              (c) => Scaffold(
                body: Builder(
                  builder: (c2) {
                    ctx = c2;
                    return const SizedBox();
                  },
                ),
              ),
        ),
      ),
    );
    final result = showConfirmDialog(
      ctx,
      title: 'Sign out?',
      message: 'You can sign back in at any time.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final action = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Sign out'),
    );
    expect(action.isDestructiveAction, isTrue);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('choices are an iOS action sheet', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final choice = showOptionsSheet<String>(
      ctx,
      title: 'This post',
      options: const [
        SheetOption(value: 'delete', label: 'Delete', isDestructive: true),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await choice, 'delete');
  });

  testWidgets('bottom sheet: grabber, and drag down to dismiss', (
    tester,
  ) async {
    _phone(tester);
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final closed = showLoomaSheet<void>(
      ctx,
      builder: (_) => const SizedBox(height: 240, child: Text('Sheet body')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-grabber')), findsOneWidget);
    expect(find.text('Sheet body'), findsOneWidget);

    await tester.drag(find.text('Sheet body'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
    await closed;
  });

  testWidgets('press and hold a post: Save, Share and Report', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ListView(
            children: [
              PostContextMenu(post: _post, child: PostCard(post: _post)),
            ],
          ),
        ),
      ),
    );
    // Press and hold (the menu opens while the finger is still down).
    final finger = await tester.startGesture(
      tester.getCenter(find.text('Scholarship tips?')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await finger.up();
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    final report = tester.widget<CupertinoActionSheetAction>(
      find.widgetWithText(CupertinoActionSheetAction, 'Report'),
    );
    expect(report.isDestructiveAction, isTrue);
  });

  // ───────────────────────── Larger text and dark mode ─────────────────────────

  for (final scale in [1.5, 2.0]) {
    testWidgets('Get help works with text at ${scale}x', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const HelpScreen(), textScale: scale));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      // Scroll the whole page: nothing overflows anywhere.
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('settings rows work with text at ${scale}x', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ListView(
              children: [
                GroupedSection(
                  header: 'Appearance',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: LoomaSegmented<QuickExitScreen>(
                        value: QuickExitScreen.weather,
                        options: {
                          for (final s in QuickExitScreen.values) s: s.label,
                        },
                        onChanged: (_) {},
                      ),
                    ),
                    GroupedSwitchRow(
                      title: 'Reduce motion',
                      subtitle:
                          'Turns off animations in Looma. Your phone\'s own '
                          'setting also works.',
                      value: false,
                      onChanged: (_) {},
                    ),
                    const GroupedRow(
                      title: 'Weather city',
                      value: 'Kuala Lumpur',
                    ),
                  ],
                ),
              ],
            ),
          ),
          textScale: scale,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dark mode: raised surfaces are lighter, never pure white', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: GroupedSection(children: [GroupedRow(title: 'App lock')]),
        ),
        theme: AppTheme.dark,
      ),
    );
    final tile = tester.widget<CupertinoListTile>(
      find.byType(CupertinoListTile),
    );
    final surface = tile.backgroundColor!;
    final background = AppTheme.dark.scaffoldBackgroundColor;
    expect(
      surface.computeLuminance(),
      greaterThan(background.computeLuminance()),
    );
    expect(surface, isNot(Colors.white));
  });
}
