import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:women_community_support/presentation/screens/me/privacy_centre_screen.dart';

/// The app's text, with Dart's split strings ('a '\n 'b') joined, so a
/// sentence can be found whole.
String _text(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r"'\s*\n\s*'"), '');

String _allAppText() {
  final buffer = StringBuffer();
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is File && f.path.endsWith('.dart')) buffer.writeln(_text(f.path));
  }
  for (final f in Directory('content').listSync()) {
    if (f is File) buffer.writeln(f.readAsStringSync());
  }
  return buffer.toString();
}

void main() {
  const screens = 'lib/presentation/screens';

  group('privacy claims say only what is true', () {
    test('no promise the app cannot keep', () {
      final all = _allAppText();
      for (final claim in [
        'never shown to anyone',
        'private and secure',
        'Share anonymously',
        'Share Anonymously',
        'Stay safe and protected',
        'Stay Safe & Protected',
        'nobody can link the two',
        'It is never linked to your posts',
        'nothing that links them to you',
        'nobody else can open your plan',
      ]) {
        expect(all, isNot(contains(claim)), reason: claim);
      }
    });

    test('the email and the women-only answer: hidden from members', () {
      expect(
        _text('$screens/auth/login_screen.dart'),
        contains(
          'We only use your email to sign you in. '
          'Other members and moderators never see it.',
        ),
      );
      final join = _text('$screens/membership/membership_flow.dart');
      expect(
        join,
        contains(
          'Your answer is private. Other members and moderators never see it.',
        ),
      );
      expect(
        join,
        contains('Only your birth year is saved. Other members never see it.'),
      );
    });

    test('onboarding: no name, and reporting (not a safety promise)', () {
      final onboarding = _text('$screens/onboarding_screen.dart');
      expect(
        onboarding,
        contains(
          'A random alias, never your name. Other members can’t see who you '
          'are.',
        ),
      );
      expect(
        onboarding,
        contains('Moderators review reports to keep Looma kind.'),
      );
    });

    test('Connect: separate from posts, for members and moderators', () {
      expect(
        _text('$screens/me/chat_profile_editor.dart'),
        contains('other members and moderators cannot link the two.'),
      );
      expect(
        _text('$screens/profile_screen.dart'),
        contains('Other members can’t link it to your posts.'),
      );
    });

    test('Privacy Centre: the Google name; what stays after deleting', () {
      final owner = PrivacyCentreScreen.sections.firstWhere(
        (s) => s.$1 == 'What the project owner can see',
      );
      expect(
        owner.$2,
        contains('(and, if you use Google, the name on your Google account)'),
      );
      expect(
        PrivacyCentreScreen.deleteSummary,
        contains(
          '"Me too" taps, poll votes and reports you made stay, with no name '
          'or account attached.',
        ),
      );
    });

    test('App lock: a forgotten PIN deletes the journal too', () {
      expect(
        _text('$screens/me/app_lock_settings_screen.dart'),
        contains('your safety plan and journal on this phone are deleted.'),
      );
      expect(
        _text('$screens/me/safety_plan_screen.dart'),
        contains('so nobody can open your plan without your PIN.'),
      );
    });
  });
}
