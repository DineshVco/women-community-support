import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/first_post_celebration.dart';
import 'package:women_community_support/presentation/widgets/heart_burst.dart';

Future<int> _one() async => 1;

void main() {
  group('FirstPostCelebration', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('celebrates once per account', () async {
      expect(
        await FirstPostCelebration.claim('amira', postCount: _one),
        isTrue,
      );
      expect(
        await FirstPostCelebration.claim('amira', postCount: _one),
        isFalse,
      );
      // A different account on the same phone gets her own first time.
      expect(await FirstPostCelebration.claim('siti', postCount: _one), isTrue);
    });

    test('not for someone who posted before (e.g. on another phone)', () async {
      expect(
        await FirstPostCelebration.claim('amira', postCount: () async => 4),
        isFalse,
      );
      // ...and never later either.
      expect(
        await FirstPostCelebration.claim('amira', postCount: _one),
        isFalse,
      );
    });

    test('still celebrates if the post count cannot be checked', () async {
      expect(
        await FirstPostCelebration.claim(
          'amira',
          postCount: () async => throw Exception('offline'),
        ),
        isTrue,
      );
    });

    test('stores the flag on the phone, per account', () async {
      await FirstPostCelebration.claim('amira', postCount: _one);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(FirstPostCelebration.keyFor('amira')), isTrue);
      expect(prefs.getBool(FirstPostCelebration.keyFor('siti')), isNull);
    });
  });

  group('showHeartBurst', () {
    Widget app({required bool reduceMotion}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showHeartBurst(context),
                    child: const Text('post'),
                  ),
                ),
              ),
        ),
      ),
    );

    testWidgets('shows blush hearts, then removes itself after 800 ms', (
      tester,
    ) async {
      await tester.pumpWidget(app(reduceMotion: false));
      await tester.tap(find.text('post'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HeartBurst), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(HeartBurst.count));

      // The 800 ms clock starts at the first frame (the 300 ms pump above).
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(HeartBurst), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byType(HeartBurst), findsNothing);
    });

    testWidgets('shows nothing when reduce motion is on', (tester) async {
      await tester.pumpWidget(app(reduceMotion: true));
      await tester.tap(find.text('post'));
      await tester.pump();

      expect(find.byType(HeartBurst), findsNothing);
    });
  });
}
