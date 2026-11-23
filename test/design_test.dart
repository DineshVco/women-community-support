import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/theme/app_typography.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('type', () {
    test('body text is Figtree, bundled with the app', () {
      expect(AppTypography.bodyFont, 'Figtree');
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Figtree');
        expect(theme.textTheme.bodySmall?.fontFamily, 'Figtree');
        // Headings stay Newsreader.
        expect(theme.textTheme.headlineLarge?.fontFamily, 'Newsreader');
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final asset = 'assets/fonts/Figtree-$weight.ttf';
        expect(pubspec, contains(asset));
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });

    test('small grey text is at least 13', () {
      final t = AppTheme.light.textTheme;
      for (final style in [t.bodySmall, t.labelMedium, t.labelSmall]) {
        expect(style!.fontSize, greaterThanOrEqualTo(13));
      }
    });

    test('no text in the app (outside the disguises) is set under 13', () {
      final small = RegExp(r'fontSize: ?(\d+(\.\d+)?)');
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        // The disguises copy stock phone apps on purpose.
        if (file.path.contains('decoy_screen')) continue;
        for (final m in small.allMatches(file.readAsStringSync())) {
          final size = double.parse(m.group(1)!);
          // 11 is allowed only for the black "Looma Team" badge.
          final allowed = file.path.contains('team_badge') ? 11 : 13;
          expect(size, greaterThanOrEqualTo(allowed), reason: file.path);
        }
      }
    });
  });

  test('one icon set: Phosphor via AppIcons (disguises excepted)', () {
    final stock = RegExp(r'(?<![A-Za-z_.])(Cupertino)?Icons\.[a-z_]+');
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll('\\', '/');
      // The weather and calculator disguises copy stock phone apps.
      if (path.contains('decoy_screen') || path.endsWith('data/weather.dart')) {
        continue;
      }
      final hits = stock.allMatches(file.readAsStringSync()).map((m) => m[0]);
      expect(hits, isEmpty, reason: path);
    }
  });

  group('grey text passes AA (4.5:1)', () {
    for (final (name, p) in [
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name: on the page, on cards and on soft fills', () {
        for (final grey in [p.textSecondary, p.textMuted]) {
          for (final bg in [p.background, p.surface, p.softFill]) {
            expect(contrast(grey, bg), greaterThanOrEqualTo(4.5));
          }
        }
      });
    }
  });
}
