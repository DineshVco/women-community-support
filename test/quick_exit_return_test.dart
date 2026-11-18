import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/security/app_lock.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/weather.dart';
import 'package:women_community_support/presentation/screens/decoy_screen.dart';
import 'package:women_community_support/presentation/screens/lock/lock_screen.dart';
import 'package:women_community_support/presentation/widgets/app_lock_gate.dart';
import 'package:women_community_support/presentation/widgets/disguise_shell.dart';
import 'package:women_community_support/presentation/widgets/posted_confirmation.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

/// Pretends to be offline (no network in tests).
class OfflineWeather extends WeatherService {
  @override
  Future<WeatherReport?> fetch(String city) async => null;
}

class FakeClock {
  DateTime now = DateTime(2026, 11, 18, 15);
  DateTime call() => now;
}

Future<void> _noSecure(bool _) async {}

void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A page with a button that opens the weather disguise in practice mode
/// (practice returns to the same page, so no Firebase is needed).
Widget _practiceApp({FakeClock? clock}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder:
        (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed:
                  () => Navigator.of(context).push(
                    QuickExit.instantRoute(
                      DecoyScreen(
                        practice: true,
                        service: OfflineWeather(),
                        clock: clock?.call,
                      ),
                    ),
                  ),
              child: const Text('Looma page'),
            ),
          ),
        ),
  ),
);

Future<void> _openWeather(WidgetTester tester, {FakeClock? clock}) async {
  _phoneScreen(tester);
  await tester.pumpWidget(_practiceApp(clock: clock));
  await tester.tap(find.text('Looma page'));
  await tester.pump();
  await tester.pump();
  expect(find.byType(DecoyScreen), findsOneWidget);
}

/// Holds a finger at [at] for [duration], then lifts it.
Future<void> _hold(
  WidgetTester tester,
  Offset at,
  Duration duration, {
  Offset move = Offset.zero,
}) async {
  final finger = await tester.startGesture(at);
  if (move != Offset.zero) {
    await tester.pump(const Duration(milliseconds: 100));
    await finger.moveBy(move);
  }
  await tester.pump(duration);
  await finger.up();
  await tester.pump();
  await tester.pump();
}

Future<void> _tripleTapTemperature(WidgetTester tester, {int taps = 3}) async {
  final temperature = find.byKey(const ValueKey('weather-temperature'));
  for (var i = 0; i < taps; i++) {
    await tester.tap(temperature);
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ───────────────────────── Press and hold ─────────────────────────

  group('press and hold for 1 second', () {
    testWidgets('anywhere: on the forecast list (a scroll area)', (
      tester,
    ) async {
      await _openWeather(tester);
      final list = tester.getCenter(find.text('5-DAY FORECAST'));
      await _hold(tester, list, const Duration(milliseconds: 1100));

      expect(find.byType(DecoyScreen), findsNothing);
      expect(find.text('Looma page'), findsOneWidget);
    });

    testWidgets('anywhere: on empty sky at the bottom', (tester) async {
      await _openWeather(tester);
      await _hold(tester, const Offset(210, 880), const Duration(seconds: 1));
      expect(find.byType(DecoyScreen), findsNothing);
    });

    testWidgets('a short press is not enough', (tester) async {
      await _openWeather(tester);
      await _hold(
        tester,
        const Offset(210, 450),
        const Duration(milliseconds: 600),
      );
      expect(find.byType(DecoyScreen), findsOneWidget);
    });

    testWidgets('scrolling does not count as a hold', (tester) async {
      await _openWeather(tester);
      await _hold(
        tester,
        const Offset(210, 600),
        const Duration(milliseconds: 1200),
        move: const Offset(0, -120),
      );
      expect(find.byType(DecoyScreen), findsOneWidget);
    });
  });

  // ───────────────────────── Triple tap ─────────────────────────

  group('triple tap on the temperature', () {
    testWidgets('3 quick taps return', (tester) async {
      await _openWeather(tester);
      await _tripleTapTemperature(tester);
      expect(find.byType(DecoyScreen), findsNothing);
      expect(find.text('Looma page'), findsOneWidget);
    });

    testWidgets('2 taps do nothing', (tester) async {
      await _openWeather(tester);
      await _tripleTapTemperature(tester, taps: 2);
      expect(find.byType(DecoyScreen), findsOneWidget);
    });
  });

  // ───────────────────────── Back button ─────────────────────────

  testWidgets('the Back button does not leave the disguise', (tester) async {
    await _openWeather(tester);
    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(handled, isTrue, reason: 'Back is used up, the app stays open');
    expect(find.byType(DecoyScreen), findsOneWidget);
  });

  // ───────────────────────── Away for a long time ─────────────────────────

  group('coming back to the phone', () {
    testWidgets('after more than 10 minutes away: back in Looma', (
      tester,
    ) async {
      final clock = FakeClock();
      await _openWeather(tester, clock: clock);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.now = clock.now.add(const Duration(minutes: 11));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.byType(DecoyScreen), findsNothing);
    });

    testWidgets('after a few minutes: still the weather', (tester) async {
      final clock = FakeClock();
      await _openWeather(tester, clock: clock);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.now = clock.now.add(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.byType(DecoyScreen), findsOneWidget);
    });
  });

  // ───────────────────────── A real Quick exit ─────────────────────────

  group('a real Quick exit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({QuickExit.introSeenKey: true});
      QuickExit.home = (_) => const Scaffold(body: Text('Looma home'));
    });

    Future<AppLock> lockWithPin() async {
      final lock = AppLock(
        MemorySecureStore(),
        hashInBackground: false,
        setSecure: _noSecure,
      );
      await lock.load();
      await lock.setPin('246810');
      return lock;
    }

    Widget app(AppLock lock) => MaterialApp(
      theme: AppTheme.light,
      builder:
          (context, child) =>
              AppLockGate(lock: lock, onForgot: () async {}, child: child!),
      home: Builder(
        builder:
            (context) => Scaffold(
              appBar: AppBar(actions: const [QuickExitButton()]),
              body: TextButton(
                onPressed:
                    () => showPostedConfirmation(context, alias: 'Quiet Fox'),
                child: const Text('Post'),
              ),
            ),
      ),
    );

    testWidgets('returns cleanly; with App lock on, the lock screen shows', (
      tester,
    ) async {
      _phoneScreen(tester);
      final lock = await lockWithPin();
      await tester.pumpWidget(app(lock));

      // A "Posted" pill is showing when she taps Quick exit.
      await tester.tap(find.text('Post'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Posted as Quiet Fox'), findsOneWidget);

      await tester.tap(find.text('Quick exit'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DecoyScreen), findsOneWidget);
      // Nothing from Looma on top of the disguise, and no lock screen.
      expect(find.text('Posted as Quiet Fox'), findsNothing);
      expect(find.byType(LockScreen), findsNothing);

      await _hold(tester, const Offset(210, 600), const Duration(seconds: 1));

      expect(find.byType(DecoyScreen), findsNothing);
      expect(find.text('Looma home'), findsOneWidget);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(lock.disguiseActive, isFalse);

      // Let the (removed) pill's timers finish.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('without App lock it goes straight back', (tester) async {
      _phoneScreen(tester);
      final lock = AppLock(
        MemorySecureStore(),
        hashInBackground: false,
        setSecure: _noSecure,
      );
      await lock.load();
      await tester.pumpWidget(app(lock));

      await tester.tap(find.text('Quick exit'));
      await tester.pump();
      await tester.pump();
      await _tripleTapTemperature(tester);

      expect(find.text('Looma home'), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);
    });

    testWidgets('both gestures together return only once', (tester) async {
      _phoneScreen(tester);
      final lock = AppLock(
        MemorySecureStore(),
        hashInBackground: false,
        setSecure: _noSecure,
      );
      await lock.load();
      await tester.pumpWidget(app(lock));
      await tester.tap(find.text('Quick exit'));
      await tester.pump();
      await tester.pump();

      // Hold on the temperature while tapping it: no error, one return.
      final temperature = tester.getCenter(
        find.byKey(const ValueKey('weather-temperature')),
      );
      await _tripleTapTemperature(tester);
      await _hold(tester, temperature, const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Looma home'), findsOneWidget);
    });
  });

  test('the hold takes 1 second and allows a little finger movement', () {
    expect(DisguiseShell.holdDuration, const Duration(seconds: 1));
    expect(DisguiseShell.holdSlop, greaterThan(0));
    expect(DisguiseShell.autoReturnAfter, const Duration(minutes: 10));
  });
}
