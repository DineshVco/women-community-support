import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native splash (before Flutter starts): the Looma logo on cream.
void main() {
  const res = 'android/app/src/main/res';

  test('Android: the logo on cream #FEF7F2', () {
    for (final folder in ['drawable', 'drawable-v21']) {
      final xml = File('$res/$folder/launch_background.xml').readAsStringSync();
      expect(xml, contains('@color/splash_background'), reason: folder);
      expect(xml, contains('@drawable/splash_logo'), reason: folder);
    }
    expect(
      File('$res/values/splash.xml').readAsStringSync(),
      contains('#FEF7F2'),
    );
    for (final bucket in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final file = File('$res/drawable-$bucket/splash_logo.webp');
      expect(file.existsSync(), isTrue, reason: bucket);
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
    }
  });

  test('Android 12+: the system splash is cream too', () {
    for (final folder in ['values-v31', 'values-night-v31']) {
      expect(
        File('$res/$folder/styles.xml').readAsStringSync(),
        contains(
          '<item name="android:windowSplashScreenBackground">'
          '@color/splash_background</item>',
        ),
        reason: folder,
      );
    }
  });

  test('iOS: the logo on cream', () {
    final storyboard =
        File(
          'ios/Runner/Base.lproj/LaunchScreen.storyboard',
        ).readAsStringSync();
    // #FEF7F2 = 254, 247, 242.
    expect(storyboard, contains('red="0.99607843137254903"'));
    expect(storyboard, contains('green="0.96862745098039216"'));
    expect(storyboard, contains('blue="0.94901960784313721"'));
    expect(storyboard, contains('<image name="LaunchImage" width="180"'));
    for (final name in ['LaunchImage', 'LaunchImage@2x', 'LaunchImage@3x']) {
      final file = File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/$name.png',
      );
      // A real picture now (the default was a 1 px placeholder).
      expect(file.lengthSync(), greaterThan(5 * 1024), reason: name);
    }
  });
}
