import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/security/app_lock.dart';
import 'package:women_community_support/core/security/pin_hasher.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/screens/lock/lock_screen.dart';
import 'package:women_community_support/presentation/widgets/app_lock_gate.dart';

/// A clock the tests can move forward.
class FakeClock {
  DateTime now = DateTime(2026, 11, 18, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

Future<AppLock> lockWithPin(
  MemorySecureStore store,
  FakeClock clock, {
  String pin = '246810',
}) async {
  final lock = AppLock(
    store,
    clock: clock.call,
    hashInBackground: false,
    setSecure: _noSecure,
  );
  await lock.load();
  await lock.setPin(pin);
  return lock;
}

void main() {
  // ───────────────────────── PIN hash ─────────────────────────

  group('PinHasher', () {
    test('PBKDF2-HMAC-SHA256 matches an independent implementation', () {
      // Python: hashlib.pbkdf2_hmac('sha256', b'123456', b'0123456789abcdef', 1000, 32)
      final out = PinHasher.pbkdf2(
        utf8.encode('123456'),
        utf8.encode('0123456789abcdef'),
        1000,
      );
      expect(base64Encode(out), 'imjQBxEeE9WAa1HwKi1UL6Lhnt9Un0JiSp0wZ055Jgo=');
    });

    test('stores a salted hash, never the PIN', () {
      final stored = PinHasher.hash('246810');
      expect(stored, isNot(contains('246810')));
      expect(stored, startsWith('pbkdf2-sha256\$${PinHasher.iterations}\$'));
      expect(PinHasher.verify('246810', stored), isTrue);
      expect(PinHasher.verify('246811', stored), isFalse);
    });

    test('the same PIN gives a different hash each time (random salt)', () {
      expect(PinHasher.hash('246810'), isNot(PinHasher.hash('246810')));
    });

    test('rejects damaged or foreign values', () {
      expect(PinHasher.verify('246810', 'not-a-hash'), isFalse);
      expect(PinHasher.verify('246810', 'md5\$1\$AA==\$AA=='), isFalse);
    });

    test('only 6 digits are valid PINs', () {
      expect(PinHasher.isValidPin('123456'), isTrue);
      for (final bad in ['12345', '1234567', '12345a', '']) {
        expect(PinHasher.isValidPin(bad), isFalse, reason: bad);
      }
    });
  });

  group('PinLockout', () {
    test('the wait grows: 5 wrong tries means 1 minute', () {
      expect(PinLockout.delayAfter(1), Duration.zero);
      expect(PinLockout.delayAfter(2), Duration.zero);
      expect(PinLockout.delayAfter(3), const Duration(seconds: 5));
      expect(PinLockout.delayAfter(4), const Duration(seconds: 15));
      expect(PinLockout.delayAfter(5), const Duration(minutes: 1));
      expect(PinLockout.delayAfter(9), const Duration(minutes: 1));
    });
  });

  // ───────────────────────── AppLock ─────────────────────────

  group('AppLock', () {
    late MemorySecureStore store;
    late FakeClock clock;

    setUp(() {
      store = MemorySecureStore();
      clock = FakeClock();
    });

    test('setting a PIN turns it on, with the app preview hidden', () async {
      final lock = await lockWithPin(store, clock);
      expect(lock.enabled, isTrue);
      expect(lock.locked, isFalse);
      expect(lock.hidePreview, isTrue);
      expect(store.values[AppLock.pinKey], isNot(contains('246810')));
    });

    test('right PIN unlocks; wrong PIN does not', () async {
      final lock = await lockWithPin(store, clock);
      lock.lockNow();
      expect(await lock.verify('111111'), PinResult.wrong);
      expect(lock.locked, isTrue);
      expect(await lock.verify('246810'), PinResult.ok);
      expect(lock.locked, isFalse);
      expect(lock.wrongTries, 0);
    });

    test(
      '5 wrong tries: wait 1 minute, even after restarting the app',
      () async {
        final lock = await lockWithPin(store, clock);
        for (var i = 0; i < 4; i++) {
          clock.advance(const Duration(minutes: 1)); // let earlier waits pass
          expect(await lock.verify('000000'), PinResult.wrong);
        }
        clock.advance(const Duration(minutes: 1));
        expect(await lock.verify('000000'), PinResult.wrong);
        expect(lock.waitLeft, const Duration(minutes: 1));

        // Even the right PIN is refused while waiting.
        expect(await lock.verify('246810'), PinResult.wait);

        // Restarting the app does not reset the wait.
        final again = AppLock(
          store,
          clock: clock.call,
          hashInBackground: false,
          setSecure: _noSecure,
        );
        await again.load();
        expect(again.locked, isTrue);
        expect(again.waitLeft, const Duration(minutes: 1));

        clock.advance(const Duration(seconds: 61));
        expect(await again.verify('246810'), PinResult.ok);
        expect(again.waitLeft, Duration.zero);
      },
    );

    test('locks after the chosen time in the background', () async {
      final lock = await lockWithPin(store, clock);
      await lock.setLockAfter(LockAfter.seconds30);

      lock.onBackground();
      clock.advance(const Duration(seconds: 10));
      lock.onForeground();
      expect(lock.locked, isFalse, reason: 'back within 30 seconds');

      lock.onBackground();
      clock.advance(const Duration(seconds: 31));
      lock.onForeground();
      expect(lock.locked, isTrue);
    });

    test('"Immediately" locks on any return', () async {
      final lock = await lockWithPin(store, clock);
      lock.onBackground();
      lock.onForeground();
      expect(lock.locked, isTrue);
    });

    test('a fresh start is locked', () async {
      await lockWithPin(store, clock);
      final restarted = AppLock(
        store,
        clock: clock.call,
        hashInBackground: false,
        setSecure: _noSecure,
      );
      await restarted.load();
      expect(restarted.locked, isTrue);
    });

    test('turning it off removes the PIN from the phone', () async {
      final lock = await lockWithPin(store, clock);
      await lock.disable();
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(store.values.containsKey(AppLock.pinKey), isFalse);
    });

    test('no PIN: nothing ever locks', () async {
      final lock = AppLock(
        store,
        clock: clock.call,
        hashInBackground: false,
        setSecure: _noSecure,
      );
      await lock.load();
      lock.onBackground();
      clock.advance(const Duration(hours: 1));
      lock.onForeground();
      lock.lockNow();
      expect(lock.locked, isFalse);
    });
  });

  // ───────────────────────── Lock screen ─────────────────────────

  group('LockScreen', () {
    late MemorySecureStore store;
    late FakeClock clock;

    setUp(() {
      store = MemorySecureStore();
      clock = FakeClock();
    });

    Future<void> typePin(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.bySemanticsLabel(d));
        await tester.pump();
      }
      await tester.pump();
    }

    Widget app(Widget child) =>
        MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

    testWidgets('wordmark, dots and keypad; nothing about the contents', (
      tester,
    ) async {
      final lock = await lockWithPin(store, clock);
      await tester.pumpWidget(app(LockScreen(lock: lock)));

      expect(find.text('Enter your PIN'), findsOneWidget);
      for (final d in '0123456789'.split('')) {
        expect(find.bySemanticsLabel(d), findsOneWidget);
      }
      // Only these words: no posts, names, plan or anything else.
      final words =
          tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
              .where((w) => w.length > 1)
              .toSet();
      expect(
        words.difference({'Enter your PIN', 'Forgot PIN', 'Looma'}),
        isEmpty,
        reason: '$words',
      );
    });

    testWidgets('wrong PIN says so; right PIN unlocks', (tester) async {
      final lock = await lockWithPin(store, clock);
      lock.lockNow();
      var unlocked = false;
      await tester.pumpWidget(
        app(LockScreen(lock: lock, onUnlocked: () => unlocked = true)),
      );

      await typePin(tester, '135791');
      expect(find.text('That PIN is not right.'), findsOneWidget);
      expect(unlocked, isFalse);

      await tester.pump(const Duration(milliseconds: 400)); // shake ends
      await typePin(tester, '246810');
      expect(unlocked, isTrue);
      expect(lock.locked, isFalse);
    });

    testWidgets('after 3 wrong tries it asks her to wait', (tester) async {
      final lock = await lockWithPin(store, clock);
      await tester.pumpWidget(app(LockScreen(lock: lock)));

      for (var i = 0; i < 3; i++) {
        await typePin(tester, '000000');
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.textContaining('Too many tries'), findsOneWidget);
      // The keypad is off while waiting.
      await tester.tap(find.bySemanticsLabel('1'));
      await tester.pump();
      final dots = tester.getSemantics(
        find.bySemanticsLabel(RegExp('digits entered')),
      );
      expect(dots.label, '0 of 6 digits entered');
      await tester.pumpWidget(const SizedBox()); // stop the countdown timer
    });

    testWidgets('Forgot PIN explains, then calls the reset', (tester) async {
      final lock = await lockWithPin(store, clock);
      var reset = false;
      await tester.pumpWidget(
        app(LockScreen(lock: lock, onForgot: () async => reset = true)),
      );
      await tester.tap(find.text('Forgot PIN'));
      await tester.pump();
      expect(find.textContaining('stay on the server'), findsOneWidget);
      expect(find.textContaining('safety plan'), findsOneWidget);

      await tester.tap(find.text('Sign out and reset'));
      await tester.pump();
      expect(reset, isTrue);
    });

    testWidgets('no "Forgot PIN" when only confirming the PIN', (tester) async {
      final lock = await lockWithPin(store, clock);
      await tester.pumpWidget(
        app(LockScreen(lock: lock, title: 'Enter your PIN to continue')),
      );
      expect(find.text('Forgot PIN'), findsNothing);
    });
  });

  // ───────────────────────── Gate ─────────────────────────

  group('AppLockGate', () {
    testWidgets('covers the app while locked, never over a disguise', (
      tester,
    ) async {
      final lock = await lockWithPin(MemorySecureStore(), FakeClock());
      lock.lockNow();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (context, child) =>
                  AppLockGate(lock: lock, onForgot: () async {}, child: child!),
          home: const Scaffold(body: Text('Private page')),
        ),
      );
      expect(find.byType(LockScreen), findsOneWidget);

      lock.disguiseActive = true;
      await tester.pump();
      expect(find.byType(LockScreen), findsNothing);

      lock.disguiseActive = false;
      await tester.pump();
      expect(find.byType(LockScreen), findsOneWidget);
    });

    testWidgets('blank cover in the app switcher when "hide preview" is on', (
      tester,
    ) async {
      final lock = await lockWithPin(MemorySecureStore(), FakeClock());
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) =>
                  AppLockGate(lock: lock, onForgot: () async {}, child: child!),
          home: const Scaffold(body: Text('Private page')),
        ),
      );
      expect(find.byKey(const ValueKey('privacy-cover')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const ValueKey('privacy-cover')), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('privacy-cover')), findsNothing);
    });
  });
}

Future<void> _noSecure(bool _) async {}
