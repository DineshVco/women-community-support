import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Weather for the Quick exit disguise.
///
/// Live from Open-Meteo (free, no API key, no location permission: only the
/// city name from Settings is sent). The last result is cached on the
/// phone. With no internet it falls back to a believable offline forecast.
class WeatherReport {
  const WeatherReport({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.wind,
    required this.code,
    required this.isDay,
    required this.updatedAt,
    required this.days,
    this.live = false,
  });

  final String city;
  final int temperature;
  final int feelsLike;
  final int humidity;
  final int wind;

  /// WMO weather code (what Open-Meteo returns).
  final int code;
  final bool isDay;
  final DateTime updatedAt;
  final List<WeatherDay> days;

  /// From Open-Meteo (true) or made up offline (false).
  final bool live;

  String get condition => WeatherCodes.label(code, isDay: isDay);
  IconData get icon => WeatherCodes.icon(code, isDay: isDay);

  Map<String, dynamic> toJson() => {
    'city': city,
    'temperature': temperature,
    'feelsLike': feelsLike,
    'humidity': humidity,
    'wind': wind,
    'code': code,
    'isDay': isDay,
    'updatedAt': updatedAt.toIso8601String(),
    'days': [for (final d in days) d.toJson()],
  };

  factory WeatherReport.fromJson(Map<String, dynamic> json) => WeatherReport(
    city: json['city'] as String,
    temperature: json['temperature'] as int,
    feelsLike: json['feelsLike'] as int,
    humidity: json['humidity'] as int,
    wind: json['wind'] as int,
    code: json['code'] as int,
    isDay: json['isDay'] as bool,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    days: [
      for (final d in json['days'] as List)
        WeatherDay.fromJson(d as Map<String, dynamic>),
    ],
    live: true,
  );

  /// Reads Open-Meteo's forecast response.
  factory WeatherReport.fromOpenMeteo(
    String city,
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final dates = (daily['time'] as List).cast<String>();
    int round(Object? v) => (v as num).round();

    return WeatherReport(
      city: city,
      temperature: round(current['temperature_2m']),
      feelsLike: round(current['apparent_temperature']),
      humidity: round(current['relative_humidity_2m']),
      wind: round(current['wind_speed_10m']),
      code: round(current['weather_code']),
      isDay: current['is_day'] == 1,
      updatedAt: now,
      live: true,
      days: [
        for (var i = 0; i < dates.length && i < 5; i++)
          WeatherDay(
            date: DateTime.parse(dates[i]),
            code: round((daily['weather_code'] as List)[i]),
            high: round((daily['temperature_2m_max'] as List)[i]),
            low: round((daily['temperature_2m_min'] as List)[i]),
          ),
      ],
    );
  }

  /// A believable forecast made on the phone (tropical city), the same all
  /// day so it does not change if someone looks twice.
  factory WeatherReport.offline(String city, DateTime now) {
    const codes = [
      0,
      2,
      3,
      80,
      95,
    ]; // sunny, partly cloudy, cloudy, showers, storms
    final days = <WeatherDay>[];
    for (var i = 0; i < 5; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      final random = Random(date.year * 10000 + date.month * 100 + date.day);
      days.add(
        WeatherDay(
          date: date,
          code: codes[random.nextInt(codes.length)],
          high: 31 + random.nextInt(4),
          low: 23 + random.nextInt(3),
        ),
      );
    }
    final today = days.first;
    final hour = now.hour;
    final warmth = hour >= 6 && hour <= 18 ? sin((hour - 6) / 12 * pi) : 0.0;
    final temperature = (today.low + (today.high - today.low) * warmth).round();
    final random = Random(now.year * 10000 + now.month * 100 + now.day + 7);

    return WeatherReport(
      city: city,
      temperature: temperature,
      feelsLike: temperature + 2 + random.nextInt(3),
      humidity: 70 + random.nextInt(18),
      wind: 5 + random.nextInt(9),
      code: today.code,
      isDay: hour >= 7 && hour < 19,
      updatedAt: DateTime(now.year, now.month, now.day, hour),
      days: days,
    );
  }
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.code,
    required this.high,
    required this.low,
  });

  final DateTime date;
  final int code;
  final int high;
  final int low;

  String get condition => WeatherCodes.label(code);
  IconData get icon => WeatherCodes.icon(code);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'code': code,
    'high': high,
    'low': low,
  };

  factory WeatherDay.fromJson(Map<String, dynamic> json) => WeatherDay(
    date: DateTime.parse(json['date'] as String),
    code: json['code'] as int,
    high: json['high'] as int,
    low: json['low'] as int,
  );
}

/// WMO weather codes (used by Open-Meteo) to words and outlined icons.
class WeatherCodes {
  WeatherCodes._();

  static String label(int code, {bool isDay = true}) => switch (code) {
    0 => isDay ? 'Sunny' : 'Clear',
    1 => isDay ? 'Mostly sunny' : 'Mostly clear',
    2 => 'Partly cloudy',
    3 => 'Cloudy',
    45 || 48 => 'Fog',
    >= 51 && <= 57 => 'Drizzle',
    >= 61 && <= 67 => 'Rain',
    >= 71 && <= 77 || 85 || 86 => 'Snow',
    >= 80 && <= 82 => 'Showers',
    >= 95 => 'Thunderstorms',
    _ => 'Cloudy',
  };

  static IconData icon(int code, {bool isDay = true}) => switch (code) {
    0 || 1 => isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
    2 => Icons.wb_cloudy_outlined,
    45 || 48 => Icons.foggy,
    >= 51 && <= 67 || >= 80 && <= 82 => Icons.grain,
    >= 71 && <= 77 || 85 || 86 => Icons.ac_unit,
    >= 95 => Icons.thunderstorm_outlined,
    _ => Icons.cloud_outlined,
  };
}

/// Fetches and caches the weather.
class WeatherService {
  WeatherService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;

  static const String cacheKey = 'looma.weather.cache';

  /// Older cached forecasts are not shown (their "Today" would be wrong).
  static const Duration maxCacheAge = Duration(hours: 3);
  static const Duration timeout = Duration(seconds: 6);

  /// What to show straight away: a recent cached report for this city, or
  /// the offline version.
  Future<WeatherReport> instant(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final cached = WeatherReport.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        final age = _clock().difference(cached.updatedAt);
        if (cached.city.toLowerCase() == city.toLowerCase() &&
            age >= Duration.zero &&
            age < maxCacheAge) {
          return cached;
        }
      }
    } catch (_) {}
    return WeatherReport.offline(city, _clock());
  }

  /// Live weather, or null when offline or the city is not found.
  Future<WeatherReport?> fetch(String city) async {
    try {
      final place = await _client
          .get(
            Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
              'name': city,
              'count': '1',
              'language': 'en',
              'format': 'json',
            }),
          )
          .timeout(timeout);
      if (place.statusCode != 200) return null;
      final results =
          (jsonDecode(place.body) as Map<String, dynamic>)['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;

      final forecast = await _client
          .get(
            Uri.https('api.open-meteo.com', '/v1/forecast', {
              'latitude': '${first['latitude']}',
              'longitude': '${first['longitude']}',
              'current':
                  'temperature_2m,apparent_temperature,relative_humidity_2m,'
                  'wind_speed_10m,weather_code,is_day',
              'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
              'timezone': 'auto',
              'forecast_days': '5',
            }),
          )
          .timeout(timeout);
      if (forecast.statusCode != 200) return null;

      final report = WeatherReport.fromOpenMeteo(
        city,
        jsonDecode(forecast.body) as Map<String, dynamic>,
        _clock(),
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(report.toJson()));
      } catch (_) {}
      return report;
    } catch (_) {
      return null;
    }
  }
}
