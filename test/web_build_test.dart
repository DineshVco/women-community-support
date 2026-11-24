import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the web download small.
void main() {
  test('icons use only the Regular and Fill weights (the others are '
      'taken out of the web build)', () {
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final weight in ['Thin', 'Light', 'Bold', 'Duotone']) {
        expect(
          text.contains('PhosphorIcons$weight'),
          isFalse,
          reason: '${file.path} uses PhosphorIcons$weight',
        );
      }
      // The style-picking helpers could reach any weight.
      expect(text.contains('PhosphorIconsStyle'), isFalse, reason: file.path);
    }
    final trim = File('tool/trim_web_build.mjs').readAsStringSync();
    expect(trim, contains("'packages/phosphor_flutter/PhosphorRegular'"));
    expect(trim, contains("'packages/phosphor_flutter/PhosphorFill'"));
  });

  test('the trim runs before every hosting deploy', () {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    expect(
      (hosting['predeploy'] as List).join(' '),
      contains('tool/trim_web_build.mjs'),
    );
    // Engine files: kept a week; this rule comes last, so it wins.
    final headers = hosting['headers'] as List;
    expect((headers.last as Map)['source'], '/canvaskit/**');
    // The app code: kept a year (its address changes with every build),
    // after the general no-cache rule for scripts so it wins.
    final sources = [for (final h in headers) (h as Map)['source']];
    final appCode = sources.indexOf('/main.dart.js');
    expect(appCode, greaterThan(sources.indexOf('**/*.@(js|json|wasm|mjs)')));
    expect(
      jsonEncode(headers[appCode]),
      contains('max-age=31536000, immutable'),
    );
  });

  test('the first screens use small pictures; no unused font', () {
    for (final name in ['looma_character', 'looma_heart', 'looma_sparks']) {
      final file = File('assets/images/$name.webp');
      expect(file.existsSync(), isTrue, reason: name);
      expect(File('assets/images/$name.png').existsSync(), isFalse);
    }
    expect(
      File('assets/images/looma_character.webp').lengthSync(),
      lessThan(80 * 1024),
    );
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('Caveat-Regular')),
    );
  });
}
