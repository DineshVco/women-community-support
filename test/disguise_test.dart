import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/security/app_lock.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/weather.dart';
import 'package:women_community_support/presentation/providers/app_settings.dart';
import 'package:women_community_support/presentation/screens/decoy_screen.dart';
import 'package:women_community_support/presentation/widgets/app_lock_gate.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

/// Pretends to be offline.
class OfflineWeather extends WeatherService {
  @override
  Future<WeatherReport?> fetch(String city) async => null;
}

final _day = DateTime(2026, 11, 18, 15); // a Wednesday afternoon

/// A small Open-Meteo answer (geocoding, then forecast).
http.Client _fakeOpenMeteo({List<Uri>? calls}) => MockClient((request) async {
  calls?.add(request.url);
  if (request.url.host.startsWith('geocoding')) {
    return http.Response(
      jsonEncode({
        'results': [
          {'name': 'Penang', 'latitude': 5.41, 'longitude': 100.33},
        ],
      }),
      200,
    );
  }
  return http.Response(
    jsonEncode({
      'current': {
        'temperature_2m': 29.6,
        'apparent_temperature': 34.2,
        'relative_humidity_2m': 79,
        'wind_speed_10m': 11.4,
        'weather_code': 95,
        'is_day': 1,
      },
      'daily': {
        'time': [
          '2026-11-18',
          '2026-11-19',
          '2026-11-20',
          '2026-11-21',
          '2026-11-22',
        ],
        'weather_code': [95, 3, 2, 0, 80],
        'temperature_2m_max': [32.1, 31.0, 33.4, 32.9, 31.5],
        'temperature_2m_min': [24.8, 24.0, 25.1, 24.6, 24.2],
      },
    }),
    200,
  );
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ───────────────────────── Calculator ─────────────────────────

  group('CalculatorEngine', () {
    String run(void Function(CalculatorEngine e) steps) {
      final e = CalculatorEngine();
      steps(e);
      return e.display;
    }

    test('× and ÷ before + and −', () {
      expect(
        run(
          (e) =>
              e
                ..digit('2')
                ..operator('+')
                ..digit('3')
                ..operator('×')
                ..digit('4')
                ..equals(),
        ),
        '14',
      );
    });

    test('decimals, division, percent, sign', () {
      expect(
        run(
          (e) =>
              e
                ..digit('1')
                ..digit('0')
                ..operator('÷')
                ..digit('4')
                ..equals(),
        ),
        '2.5',
      );
      expect(
        run(
          (e) =>
              e
                ..digit('5')
                ..decimal()
                ..digit('5')
                ..operator('−')
                ..digit('1')
                ..equals(),
        ),
        '4.5',
      );
      expect(
        run(
          (e) =>
              e
                ..digit('5')
                ..digit('0')
                ..percent(),
        ),
        '0.5',
      );
      expect(
        run(
          (e) =>
              e
                ..digit('7')
                ..toggleSign(),
        ),
        '-7',
      );
    });

    test('dividing by zero shows Error, AC clears', () {
      final e =
          CalculatorEngine()
            ..digit('7')
            ..operator('÷')
            ..digit('0')
            ..equals();
      expect(e.display, 'Error');
      e.clear();
      expect(e.display, '0');
    });

    test('plainEntry is only digits with no operator', () {
      final e =
          CalculatorEngine()
            ..digit('2')
            ..digit('4');
      expect(e.plainEntry, '24');
      e.operator('+');
      expect(e.plainEntry, isNull);
    });
  });

  group('Calculator disguise', () {
    Future<AppLock> pinLock() async {
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
      builder: (context, child) => AppLockScope(lock: lock, child: child!),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        QuickExit.instantRoute(
                          const CalculatorDisguise(practice: true),
                        ),
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
      ),
    );

    Finder key(String label) =>
        find.descendant(of: find.byType(InkWell), matching: find.text(label));

    Future<void> press(WidgetTester tester, String keys) async {
      for (final k in keys.split('')) {
        await tester.tap(key(k));
        await tester.pump();
      }
    }

    String display(WidgetTester tester) =>
        tester
            .widget<Text>(find.byKey(const ValueKey('calculator-display')))
            .data!;

    testWidgets('a working calculator', (tester) async {
      await tester.pumpWidget(app(await pinLock()));
      await tester.tap(find.text('Open'));
      await tester.pump();

      await press(tester, '12+30×2=');
      expect(display(tester), '72');
      expect(tester.takeException(), isNull);
    });

    testWidgets('her PIN and "=" brings her back', (tester) async {
      final lock = await pinLock();
      await tester.pumpWidget(app(lock));
      await tester.tap(find.text('Open'));
      await tester.pump();

      await press(tester, '246810=');
      await tester.pump();
      expect(find.byType(CalculatorDisguise), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a wrong PIN is just a number, and counts as a wrong try', (
      tester,
    ) async {
      final lock = await pinLock();
      await tester.pumpWidget(app(lock));
      await tester.tap(find.text('Open'));
      await tester.pump();

      await press(tester, '111111=');
      expect(find.byType(CalculatorDisguise), findsOneWidget);
      expect(display(tester), '111111');
      expect(lock.wrongTries, 1);
    });

    testWidgets('with a PIN, pressing and holding does nothing', (
      tester,
    ) async {
      await tester.pumpWidget(app(await pinLock()));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.longPress(find.byKey(const ValueKey('calculator-display')));
      await tester.pump();
      expect(find.byType(CalculatorDisguise), findsOneWidget);
    });

    testWidgets('no PIN: press and hold the numbers to come back', (
      tester,
    ) async {
      final lock = AppLock(
        MemorySecureStore(),
        hashInBackground: false,
        setSecure: _noSecure,
      );
      await lock.load();
      await tester.pumpWidget(app(lock));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.longPress(find.byKey(const ValueKey('calculator-display')));
      await tester.pump();
      expect(find.byType(CalculatorDisguise), findsNothing);
    });
  });

  // ───────────────────────── Weather ─────────────────────────

  group('weather', () {
    test('offline: 5 plausible days, the same all day', () {
      final a = WeatherReport.offline('Kuala Lumpur', _day);
      final b = WeatherReport.offline(
        'Kuala Lumpur',
        _day.add(const Duration(minutes: 20)),
      );
      expect(a.days, hasLength(5));
      for (final d in a.days) {
        expect(d.high, inInclusiveRange(31, 34));
        expect(d.low, inInclusiveRange(23, 25));
      }
      expect(a.days.map((d) => d.code), b.days.map((d) => d.code));
      expect(a.temperature, b.temperature);
      expect(a.live, isFalse);
    });

    test('no sunshine at night', () {
      for (var d = 0; d < 60; d++) {
        final night = WeatherReport.offline(
          'Kuala Lumpur',
          DateTime(2026, 1, 1 + d, 23),
        );
        expect(night.condition, isNot('Sunny'));
      }
    });

    test('WMO codes become words and icons', () {
      expect(WeatherCodes.label(0), 'Sunny');
      expect(WeatherCodes.label(0, isDay: false), 'Clear');
      expect(WeatherCodes.label(3), 'Cloudy');
      expect(WeatherCodes.label(63), 'Rain');
      expect(WeatherCodes.label(81), 'Showers');
      expect(WeatherCodes.label(96), 'Thunderstorms');
      expect(WeatherCodes.icon(95), Icons.thunderstorm_outlined);
    });

    test('live from Open-Meteo: city only, no key, then cached', () async {
      final calls = <Uri>[];
      final service = WeatherService(
        client: _fakeOpenMeteo(calls: calls),
        clock: () => _day,
      );
      final report = await service.fetch('Penang');

      expect(report, isNotNull);
      expect(report!.live, isTrue);
      expect(report.temperature, 30);
      expect(report.feelsLike, 34);
      expect(report.condition, 'Thunderstorms');
      expect(report.days, hasLength(5));
      expect(report.days[3].condition, 'Sunny');

      // Only the city name is sent: no location, no key.
      expect(calls.first.queryParameters['name'], 'Penang');
      for (final call in calls) {
        expect(call.queryParameters.keys, isNot(contains('apikey')));
      }

      // Shown straight away next time, from the cache.
      final cached = await WeatherService(clock: () => _day).instant('Penang');
      expect(cached.live, isTrue);
      expect(cached.temperature, 30);
    });

    test('offline or a failure: the believable version instead', () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('down', 503)),
        clock: () => _day,
      );
      expect(await service.fetch('Kuala Lumpur'), isNull);
      final shown = await service.instant('Kuala Lumpur');
      expect(shown.live, isFalse);
      expect(shown.city, 'Kuala Lumpur');
    });

    test('an old cache is not shown (its "Today" would be wrong)', () async {
      final service = WeatherService(
        client: _fakeOpenMeteo(),
        clock: () => _day,
      );
      await service.fetch('Penang');
      final later = WeatherService(
        clock: () => _day.add(const Duration(hours: 5)),
      );
      expect((await later.instant('Penang')).live, isFalse);
    });

    testWidgets('weather screen: city from Settings, 5 days, no Looma', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) => AppSettingsScope(
                settings: AppSettings(weatherCity: 'Ipoh'),
                child: child!,
              ),
          home: DecoyScreen(now: _day, service: OfflineWeather()),
        ),
      );
      await tester.pump();
      expect(find.text('Ipoh'), findsOneWidget);
      expect(find.text('5-DAY FORECAST'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.textContaining('Looma'), findsNothing);
      expect(find.textContaining('Practice'), findsNothing);
    });
  });

  // ───────────────────────── Choosing the disguise ─────────────────────────

  testWidgets('Settings choose which screen Quick exit shows', (tester) async {
    SharedPreferences.setMockInitialValues({QuickExit.introSeenKey: true});
    final settings = AppSettings(quickExitScreen: QuickExitScreen.calculator);
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) =>
                AppSettingsScope(settings: settings, child: child!),
        home: Scaffold(
          appBar: AppBar(actions: const [QuickExitButton()]),
          body: const Text('Looma page'),
        ),
      ),
    );
    await tester.tap(find.text('Quick exit'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CalculatorDisguise), findsOneWidget);
    expect(find.text('Looma page'), findsNothing);
  });
}

Future<void> _noSecure(bool _) async {}
