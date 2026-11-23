import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/app_shell.dart';
import 'package:women_community_support/presentation/widgets/poll_view.dart';
import 'package:women_community_support/presentation/widgets/post_route.dart';
import 'package:women_community_support/presentation/widgets/press_scale.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
  home: home,
);

/// A feed with one card that opens a post.
class _Feed extends StatelessWidget {
  const _Feed();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('card'),
        onPressed:
            () => Navigator.of(context).push(
              PostRoute<void>(
                builder: (_) => const Scaffold(body: Text('The post')),
              ),
            ),
        child: const Text('A card'),
      ),
    ),
  );
}

/// Counts taps, to show a tab keeps its state.
class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('${widget.name} $taps'),
    ),
  );
}

/// Which tab is showing (changed by the tests).
final ValueNotifier<int> _tab = ValueNotifier(0);

Widget _tabs({bool reduceMotion = false}) => _app(
  Scaffold(
    body: ValueListenableBuilder<int>(
      valueListenable: _tab,
      builder:
          (context, index, _) => Stack(
            fit: StackFit.expand,
            children: [
              TabLayer(
                key: const ValueKey(0),
                active: index == 0,
                child: const _Counter('Discuss'),
              ),
              TabLayer(
                key: const ValueKey(1),
                active: index == 1,
                child: const _Counter('Care'),
              ),
            ],
          ),
    ),
  ),
  reduceMotion: reduceMotion,
);

double _opacityOf(WidgetTester tester, String text) =>
    tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text(text, skipOffstage: false),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

void main() {
  group('opening a post fades and rises from its card', () {
    testWidgets('fades in and rises, the feed stays still', (tester) async {
      await tester.pumpWidget(_app(const _Feed()));
      final cardAt = tester.getTopLeft(find.byKey(const ValueKey('card')));
      await tester.tap(find.byKey(const ValueKey('card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fade = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('post-route-fade')),
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      // Lower than its final place, on its way up.
      expect(tester.getTopLeft(find.text('The post')).dy, greaterThan(0));
      // The feed underneath does not slide away.
      expect(tester.getTopLeft(find.byKey(const ValueKey('card'))), cardAt);

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('The post')).dy, 0);
      // And back: it fades away again.
      Navigator.of(tester.element(find.text('The post'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('The post'), findsNothing);
    });

    testWidgets('Reduce motion: the post simply appears', (tester) async {
      await tester.pumpWidget(_app(const _Feed(), reduceMotion: true));
      await tester.tap(find.byKey(const ValueKey('card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const ValueKey('post-route-fade')), findsNothing);
      expect(tester.getTopLeft(find.text('The post')).dy, 0);
      await tester.pumpAndSettle();
    });

    test('every place that opens a post uses it', () {
      for (final path in [
        'lib/presentation/screens/home_screen.dart',
        'lib/presentation/screens/me/post_list_screen.dart',
        'lib/presentation/screens/me/my_reports_screen.dart',
        'lib/presentation/screens/moderator_screen.dart',
      ]) {
        final s = File(path).readAsStringSync().replaceAll('\r\n', '\n');
        expect(s, contains('PostRoute<void>('), reason: path);
        expect(
          RegExp(
            r'MaterialPageRoute<void>\(\s*builder:\s*\(_\) =>\s*PostDetailScreen',
          ).hasMatch(s),
          isFalse,
          reason: path,
        );
      }
    });
  });

  group('the tab content cross-fades', () {
    setUp(() => _tab.value = 0);
    testWidgets('old fades out while new fades in, state kept', (tester) async {
      await tester.pumpWidget(_tabs());
      await tester.tap(find.text('Discuss 0'));
      await tester.pump();
      expect(find.text('Discuss 1'), findsOneWidget);
      expect(find.text('Care 0'), findsNothing); // offstage

      _tab.value = 1;
      await tester.pump(const Duration(milliseconds: 100));
      // Both on stage, mid cross-fade.
      expect(find.text('Discuss 1'), findsOneWidget);
      expect(find.text('Care 0'), findsOneWidget);
      expect(_opacityOf(tester, 'Care 0'), 1);
      expect(_opacityOf(tester, 'Discuss 1'), 0);

      await tester.pumpAndSettle();
      expect(find.text('Discuss 1'), findsNothing); // offstage now
      expect(find.text('Care 0'), findsOneWidget);

      // Back to Discuss: it kept its state.
      _tab.value = 0;
      await tester.pumpAndSettle();
      expect(find.text('Discuss 1'), findsOneWidget);
    });

    testWidgets('the fading-out tab cannot be tapped', (tester) async {
      await tester.pumpWidget(_tabs());
      _tab.value = 1;
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Care 0'));
      await tester.pump();
      expect(find.text('Care 1'), findsOneWidget);
      expect(find.text('Discuss 0'), findsOneWidget); // not tapped
      await tester.pumpAndSettle();
    });

    testWidgets('Reduce motion: switches at once', (tester) async {
      await tester.pumpWidget(_tabs(reduceMotion: true));
      _tab.value = 1;
      await tester.pump();
      expect(find.text('Discuss 0'), findsNothing);
      expect(find.text('Care 0'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  test('buttons and cards press to 98%', () {
    expect(const PressScale(child: SizedBox()).scale, 0.98);
    expect(PressScale.card, 0.98);
  });

  group('light haptics', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments as String);
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('a vote', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: PollView(
              options: const ['Yes', 'No'],
              counts: const [0, 0],
              voted: false,
              onVote: (_) async {},
            ),
          ),
          reduceMotion: true,
        ),
      );
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(calls, ['HapticFeedbackType.lightImpact']);
    });

    test('post published, Me too and mood saved use the light one', () {
      String read(String p) =>
          File(p).readAsStringSync().replaceAll('\r\n', '\n');
      final home = read('lib/presentation/screens/home_screen.dart');
      expect(
        home,
        contains(
          'AppHaptics.light();\n    showPostedConfirmation(context, alias: alias);',
        ),
      );
      // Only once when publishing: the compose screen does not add one.
      expect(
        read('lib/presentation/screens/create_post_screen.dart'),
        isNot(contains('AppHaptics.medium();\n      // The feed')),
      );
      final detail = read('lib/presentation/screens/post_detail_screen.dart');
      final meToo = detail.substring(detail.indexOf('_toggleMeToo('));
      expect(
        meToo.substring(0, meToo.indexOf('setState')),
        contains('AppHaptics.light();'),
      );
      final checkIn = read('lib/presentation/widgets/check_in_row.dart');
      final pick = checkIn.substring(checkIn.indexOf('_pick(Mood mood)'));
      expect(
        pick.substring(0, pick.indexOf('store.save')),
        contains('AppHaptics.light();'),
      );
      final mood = read('lib/presentation/screens/care/mood_screen.dart');
      expect(mood, contains('AppHaptics.light();'));
    });
  });
}
