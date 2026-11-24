import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/security/app_lock.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/journal.dart';
import 'package:women_community_support/data/mood.dart';
import 'package:women_community_support/data/models/report.dart';
import 'package:women_community_support/data/models/user_profile.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/auth/login_screen.dart';
import 'package:women_community_support/presentation/screens/care/breathe_screen.dart';
import 'package:women_community_support/presentation/screens/care/ground_screen.dart';
import 'package:women_community_support/presentation/screens/care/journal_screen.dart';
import 'package:women_community_support/presentation/screens/care/mood_screen.dart';
import 'package:women_community_support/presentation/screens/create_post_screen.dart';
import 'package:women_community_support/presentation/screens/decoy_screen.dart';
import 'package:women_community_support/presentation/screens/lock/lock_screen.dart';
import 'package:women_community_support/presentation/screens/me/app_lock_settings_screen.dart';
import 'package:women_community_support/presentation/screens/me/chat_profile_editor.dart';
import 'package:women_community_support/presentation/screens/me/my_reports_screen.dart';
import 'package:women_community_support/presentation/screens/me/post_list_screen.dart';
import 'package:women_community_support/presentation/screens/me/privacy_centre_screen.dart';
import 'package:women_community_support/presentation/screens/membership/membership_flow.dart';
import 'package:women_community_support/presentation/screens/onboarding_screen.dart';
import 'package:women_community_support/presentation/widgets/app_lock_gate.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

import 'support/real_fonts.dart';

class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _NoAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Posts extends PostRepository {
  _Posts() : super(firestore: _NoDb(), auth: _NoAuth());

  @override
  Stream<List<Report>> watchMyReports() => Stream.value(const []);
}

Future<void> _noSecure(bool _) async {}

/// Every screen that must show Quick exit, as it is opened in the app.
final Map<String, Widget Function()> _screens = {
  'Sign in': () => LoginScreen(onBack: () {}),
  'Sign up': () => LoginScreen(initialSignUp: true, onBack: () {}),
  'Onboarding': () => OnboardingScreen(onGetStarted: () {}, onSignIn: () {}),
  'Join: women only': () => const MembershipFlow(profile: UserProfile()),
  'Join: birthday':
      () => const MembershipFlow(profile: UserProfile(isWoman: true)),
  'Write a post': () => const CreatePostScreen(),
  'New poll': () => const CreatePostScreen(startAsPoll: true),
  'Breathe': () => const BreatheScreen(),
  'Ground yourself': () => const GroundScreen(),
  'Mood check-in': () => MoodScreen(store: MoodStore(MemorySecureStore())),
  'Journal list':
      () => JournalScreen(
        store: JournalStore(MemorySecureStore()),
        prompts: const ['What is on my mind right now?'],
      ),
  'Journal editor (new)':
      () => JournalEditor(store: JournalStore(MemorySecureStore())),
  'Journal editor (a note)':
      () => JournalEditor(
        store: JournalStore(MemorySecureStore()),
        entry: JournalEntry(
          id: 'a',
          text: 'A note',
          createdAt: DateTime(2026, 11, 20),
          updatedAt: DateTime(2026, 11, 20),
        ),
      ),
  'Privacy Centre': () => const PrivacyCentreScreen(),
  'Saved posts':
      () => PostListScreen(
        title: 'Saved posts',
        load: () async => [],
        emptyMessage: 'Nothing saved yet.',
      ),
  'My posts':
      () => PostListScreen(
        title: 'My posts',
        load: () async => [],
        emptyMessage: 'You have not posted yet.',
      ),
  'My reports': () => const MyReportsScreen(),
  'App lock settings': () => const AppLockSettingsScreen(),
  'Choose PIN': () => SetPinScreen(onSet: (_) async {}),
  'Chat profile editor': () => ChatProfileEditor(onSave: (_) async {}),
};

/// The screen opened on top of a page (so the bar shows its back arrow),
/// on a phone [width] px wide with text at [textScale].
Future<void> _open(
  WidgetTester tester,
  Widget Function() screen, {
  double width = 320,
  double textScale = 2,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final lock = AppLock(
    MemorySecureStore(),
    hashInBackground: false,
    setSecure: _noSecure,
  );
  await lock.load();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    Provider<PostRepository>.value(
      value: _Posts(),
      child: AppLockScope(
        lock: lock,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
          home: const Scaffold(body: Text('Before')),
        ),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => screen()),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The visible pill (not its larger tap area).
Rect _pill(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(QuickExitButton),
    matching: find.byType(Material),
  ),
);

/// Every piece of text and every button on screen, except Quick exit's
/// own, must stay clear of the pill.
void _expectNothingUnderPill(WidgetTester tester, String name) {
  final pill = _pill(tester);
  final exit = find.byType(QuickExitButton);
  final others = find.byWidgetPredicate(
    (w) =>
        w is RichText ||
        w is IconButton ||
        w is TextButton ||
        w is CupertinoButton ||
        w is CupertinoNavigationBarBackButton,
  );
  for (final element in others.evaluate()) {
    final inside =
        find
            .descendant(of: exit, matching: find.byWidget(element.widget))
            .evaluate()
            .isNotEmpty;
    if (inside) continue;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) {
      continue;
    }
    // Text that is not painted (a hidden "Skip" on page 1) cannot overlap.
    if (element.widget is RichText &&
        (box as RenderParagraph).text.toPlainText().trim().isEmpty) {
      continue;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // Off-screen pages (onboarding) are not visible.
    if (rect.left >= tester.view.physicalSize.width) continue;
    final overlap = rect.intersect(pill);
    expect(
      overlap.width > 0.5 && overlap.height > 0.5,
      isFalse,
      reason:
          '$name: ${element.widget.runtimeType} at $rect overlaps Quick exit '
          'at $pill',
    );
  }
}

void main() {
  setUpAll(loadRealFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('every listed screen shows Quick exit', () {
    for (final entry in _screens.entries) {
      testWidgets(entry.key, (tester) async {
        await _open(tester, entry.value, width: 420, textScale: 1);
        expect(find.byType(QuickExitButton), findsOneWidget);
        // Top right: in the top bar, on the right half of the screen.
        final pill = _pill(tester);
        expect(pill.top, lessThan(120));
        expect(pill.left, greaterThan(420 / 2));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('320 px wide, text at 2x: nothing overlaps', () {
    for (final dark in [false, true]) {
      for (final entry in _screens.entries) {
        testWidgets('${entry.key}${dark ? ' (dark)' : ''}', (tester) async {
          await _open(tester, entry.value, dark: dark);
          expect(tester.takeException(), isNull);
          expect(find.byType(QuickExitButton), findsOneWidget);
          final pill = _pill(tester);
          expect(pill.right, lessThanOrEqualTo(320));
          expect(pill.top, greaterThanOrEqualTo(0));
          _expectNothingUnderPill(tester, entry.key);
        });
      }
    }

    testWidgets('onboarding: every page, with Skip beside Quick exit', (
      tester,
    ) async {
      await _open(tester, _screens['Onboarding']!);
      for (var page = 0; page < 4; page++) {
        _expectNothingUnderPill(tester, 'Onboarding page ${page + 1}');
        if (page > 0) {
          expect(
            tester.getRect(find.text('Skip')).right,
            lessThanOrEqualTo(_pill(tester).left),
          );
        }
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('works before she has an account', () {
    setUp(() {
      // The first-tap explanation was seen, so one tap hides Looma.
      SharedPreferences.setMockInitialValues({QuickExit.introSeenKey: true});
      QuickExit.home = (_) => const Scaffold(body: Text('Looma home'));
    });

    for (final name in ['Sign in', 'Onboarding', 'Join: women only']) {
      testWidgets(name, (tester) async {
        await _open(tester, _screens[name]!, width: 420, textScale: 1);
        await tester.tap(find.byType(QuickExitButton));
        await tester.pump();
        await tester.pump();
        expect(find.byType(DecoyScreen), findsOneWidget);
        expect(find.byType(QuickExitButton), findsNothing);
        // Press and hold to come back.
        final finger = await tester.startGesture(const Offset(210, 500));
        await tester.pump(const Duration(seconds: 1));
        await finger.up();
        await tester.pump();
        await tester.pump();
        expect(find.text('Looma home'), findsOneWidget);
      });
    }
  });

  testWidgets('Quick exit from the journal editor keeps what she wrote', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({QuickExit.introSeenKey: true});
    QuickExit.home = (_) => const Scaffold(body: Text('Looma home'));
    final store = JournalStore(MemorySecureStore());
    await _open(
      tester,
      () => JournalEditor(store: store),
      width: 420,
      textScale: 1,
    );
    await tester.enterText(find.byType(EditableText), 'Still here');
    await tester.tap(find.byType(QuickExitButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DecoyScreen), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final notes = await store.load();
    expect(notes.map((n) => n.text), ['Still here']);
  });
}
