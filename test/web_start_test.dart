import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/main.dart';
import 'package:women_community_support/presentation/widgets/web_start.dart';

void main() {
  group('web start-up', () {
    testWidgets('draws at once while it gets ready; failure offers retry', (
      tester,
    ) async {
      var starts = 0;
      Future<LoomaServices> failing() async {
        starts++;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        throw Exception('offline');
      }

      await tester.pumpWidget(WebStart(start: failing));
      // The very first frame: the loading screen, not a blank page.
      expect(find.byKey(const ValueKey('web-start')), findsOneWidget);
      expect(find.text('Looma'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.text('Looma could not start. Check your internet connection.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(starts, 2);
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('dark: the dark loading colours', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        WebStart(start: () => Completer<LoomaServices>().future),
      );
      final box = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('web-start')),
      );
      expect(box.color, WebStart.darkBackground);
    });
  });

  group('the page before Flutter starts (web/index.html)', () {
    final html = File('web/index.html').readAsStringSync();

    test('a loading screen at once: cream, the cat, "Looma", a dot', () {
      expect(html, contains('id="looma-splash"'));
      expect(html, contains('#FEF7F2'));
      expect(html, contains('icons/splash_cat.webp'));
      expect(html, contains('>Looma<'));
      expect(html, contains('class="dot"'));
      expect(
        File('web/icons/splash_cat.webp').lengthSync(),
        lessThan(20 * 1024),
      );
    });

    test('removed at the first frame; dark mode; reduced motion', () {
      expect(html, contains("'flutter-first-frame'"));
      expect(html, contains('splash.remove()'));
      expect(html, contains('prefers-color-scheme: dark'));
      expect(html, contains('prefers-reduced-motion: reduce'));
      expect(html, contains('animation: none'));
    });

    test('no service worker; old ones and their caches are removed', () {
      final boot = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(boot, contains('_flutter.loader.load()'));
      expect(boot, isNot(contains('serviceWorkerSettings')));
      expect(boot, contains('r.unregister()'));
      expect(boot, contains('caches.delete'));
    });
  });

  test('Firestore uses long polling on the web only', () {
    final main = File(
      'lib/main.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final i = main.indexOf('webExperimentalForceLongPolling: true');
    expect(i, greaterThan(0));
    // Inside `if (kIsWeb)`.
    expect(
      main.substring(main.lastIndexOf('if (kIsWeb)', i), i),
      isNot(contains('}')),
    );
  });
}
