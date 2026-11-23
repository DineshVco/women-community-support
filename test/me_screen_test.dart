import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/models/chat_profile.dart';
import 'package:women_community_support/data/models/user_profile.dart';
import 'package:women_community_support/data/repositories/chat_repository.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/providers/app_settings.dart';
import 'package:women_community_support/presentation/providers/theme_provider.dart';
import 'package:women_community_support/presentation/screens/me/privacy_centre_screen.dart';
import 'package:women_community_support/presentation/screens/profile_screen.dart';
import 'package:women_community_support/presentation/widgets/cat_avatar.dart';
import 'package:women_community_support/presentation/widgets/ios.dart';

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
  Stream<UserProfile> watchProfile() =>
      Stream.value(UserProfile.fromMap(const {}));

  @override
  Stream<bool> watchFoundingMember() => Stream.value(false);

  @override
  Future<bool> isModerator() async => false;

  @override
  Future<void> ensureCreatedAt() async {}
}

class _Chat extends ChatRepository {
  _Chat(this.profile) : super(firestore: _NoDb(), auth: _NoAuth());

  final ChatProfile? profile;

  @override
  Stream<ChatProfile?> watchMine() => Stream.value(profile);
}

Future<void> _pumpMe(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = AppSettings();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PostRepository>.value(value: _Posts()),
        Provider<ChatRepository>.value(
          value: _Chat(
            const ChatProfile(alias: 'Soft Owl', avatarId: 'cat_05'),
          ),
        ),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: AppSettingsScope(settings: settings, child: child!),
            ),
        home: const ProfileScreen(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The section a row is in (by its header).
String? _sectionOf(WidgetTester tester, String row) {
  final section = tester.widget<GroupedSection>(
    find.ancestor(of: find.text(row), matching: find.byType(GroupedSection)),
  );
  return section.header;
}

void main() {
  testWidgets('three card sections, the profile with the cat on top', (
    tester,
  ) async {
    await _pumpMe(tester);
    for (final header in ['YOUR SPACE', 'PRIVACY AND SAFETY', 'ACCOUNT']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(find.text('Soft Owl'), findsOneWidget);
    // The profile card is above every section.
    final cat = tester.getRect(find.byType(CatAvatar).first);
    expect(cat.top, lessThan(tester.getRect(find.text('YOUR SPACE')).top));

    for (final row in [
      'My posts',
      'Saved posts',
      'Safety plan',
      'My journal',
    ]) {
      expect(_sectionOf(tester, row), 'Your space', reason: row);
    }
    for (final row in [
      'Open to chat',
      'Blocked list',
      'My reports',
      'My requests',
      'App lock',
      'Quick exit disguise',
    ]) {
      expect(_sectionOf(tester, row), 'Privacy and safety', reason: row);
    }
    for (final row in ['Sign out', ProfileScreen.deleteLabel]) {
      expect(_sectionOf(tester, row), 'Account', reason: row);
    }
  });

  testWidgets('"Coming soon" rows are readable, not greyed out', (
    tester,
  ) async {
    await _pumpMe(tester);
    expect(find.text('Coming soon'), findsNWidgets(2));
    for (final row in ['My requests', 'Blocked list']) {
      final text = tester.widget<Text>(find.text(row));
      expect(text.style!.color, AppPalette.light.text, reason: row);
    }
  });

  testWidgets('Delete my account is easy to find and opens the confirmation', (
    tester,
  ) async {
    await _pumpMe(tester);
    final delete = find.text(ProfileScreen.deleteLabel);
    expect(delete, findsOneWidget);
    // Clearly marked: red, like other destructive rows.
    expect(
      tester.widget<Text>(delete).style!.color,
      isNot(AppPalette.light.text),
    );
    // It is the last row on Me.
    expect(
      tester.getRect(delete).top,
      greaterThan(tester.getRect(find.text('Sign out')).top),
    );

    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    // The privacy page, with the delete card first and its button.
    expect(find.byType(PrivacyCentreScreen), findsOneWidget);
    final button = find.text('Delete my account');
    expect(button, findsOneWidget);
    expect(
      tester.getRect(button).top,
      lessThan(tester.getRect(find.text('What other women can see')).top),
    );
  });

  testWidgets('no streaks or pressure numbers', (tester) async {
    await _pumpMe(tester);
    expect(find.textContaining('streak'), findsNothing);
    expect(find.textContaining(RegExp(r'\d+ days?')), findsNothing);
  });

  for (final (name, width, scale, theme) in [
    ('320 px, 2x text', 320.0, 2.0, AppTheme.light),
    ('dark mode', 390.0, 1.0, AppTheme.dark),
  ]) {
    testWidgets('$name: no overflow', (tester) async {
      await _pumpMe(tester, width: width, textScale: scale, theme: theme);
      expect(tester.takeException(), isNull);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });
  }
}
