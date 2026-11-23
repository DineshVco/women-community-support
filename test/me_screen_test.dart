import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_community_support/core/theme/app_colors.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/presentation/widgets/card_picture.dart';
import 'package:women_community_support/core/theme/app_icons.dart';
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
import 'package:women_community_support/presentation/widgets/looma_card.dart';
import 'package:women_community_support/presentation/widgets/quick_exit_button.dart';

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
  bool reduceMotion = false,
  double statusBar = 0,
  double height = 5000,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);
  final settings = AppSettings();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PostRepository>.value(value: _Posts()),
        Provider<ChatRepository>.value(
          value: _Chat(
            const ChatProfile(
              alias: 'Soft Owl',
              avatarId: 'cat_05',
              interests: ['health', 'money', 'friendship'],
              lookingFor: ['talk', 'study_buddy'],
            ),
          ),
        ),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reduceMotion,
              ),
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
    for (final header in ['YOUR SPACE', 'PRIVACY & SAFETY', 'ACCOUNT']) {
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
      expect(_sectionOf(tester, row), 'Privacy & safety', reason: row);
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
      final exit = find.byType(QuickExitButton);
      expect(exit, findsOneWidget);
      expect(tester.getSize(exit).height, greaterThanOrEqualTo(44));
    });
  }

  group('header: "Me" and Quick exit on one row (mockup)', () {
    testWidgets('title with its accent, Quick exit on the right', (
      tester,
    ) async {
      await _pumpMe(tester, statusBar: 47);
      final title = tester.getRect(find.text('Me'));
      final exit = find.byType(QuickExitButton);
      expect(exit, findsOneWidget);
      final exitRect = tester.getRect(exit);
      expect(title.right, lessThan(exitRect.left));
      expect(exitRect.height, greaterThanOrEqualTo(44));
      // The 24 x 3 blush accent under the title.
      final accent = tester.getRect(find.byKey(const ValueKey('title-accent')));
      expect(accent.size, const Size(24, 3));
      expect(accent.top, greaterThan(title.bottom));
    });

    testWidgets('the profile card is first, 8 px under the header', (
      tester,
    ) async {
      await _pumpMe(tester, statusBar: 47);
      final card = tester.getRect(
        find
            .ancestor(
              of: find.byType(CatAvatar).first,
              matching: find.byType(LoomaCard),
            )
            .first,
      );
      final exit = tester.getRect(find.byType(QuickExitButton));
      // Clear of Quick exit's whole tap area.
      expect(card.top, greaterThanOrEqualTo(exit.bottom));
      expect(tester.getRect(find.byType(CatAvatar).first).width, 72);
    });
  });

  group('mockup details on Me', () {
    testWidgets('small icons before the section headers', (tester) async {
      await _pumpMe(tester);
      for (final (header, icon) in [
        ('INTERESTS & LOOKING FOR', AppIcons.sectionInterests),
        ('YOUR SPACE', AppIcons.sectionSpace),
        ('PRIVACY & SAFETY', AppIcons.sectionPrivacy),
      ]) {
        final row = find.ancestor(
          of: find.text(header),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: row.first, matching: find.byIcon(icon)),
          findsOneWidget,
          reason: header,
        );
      }
    });

    testWidgets('interest chips: an icon inside, the chip colour', (
      tester,
    ) async {
      await _pumpMe(tester);
      for (final (label, id) in [
        ('Health', 'health'),
        ('Money', 'money'),
        ('Friendship', 'friendship'),
        ('Someone to talk to', 'talk'),
        ('Study buddy', 'study_buddy'),
      ]) {
        final chip =
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(Container),
                )
                .first;
        expect(
          find.descendant(
            of: chip,
            matching: find.byIcon(AppIcons.interest(id)),
          ),
          findsOneWidget,
          reason: label,
        );
        final fill =
            (tester.widget<Container>(chip).decoration! as BoxDecoration).color;
        expect(fill, AppPalette.light.chipFill, reason: label);
      }
    });

    testWidgets('profile card: blush to cream, picture on the right', (
      tester,
    ) async {
      await _pumpMe(tester);
      final card =
          find
              .ancestor(
                of: find.byType(CatAvatar).first,
                matching: find.byType(LoomaCard),
              )
              .first;
      expect(
        tester.widget<LoomaCard>(card).gradient,
        LinearGradient(colors: AppPalette.light.profileGradient),
      );
      // The magnolia picture is not in the project yet: a soft gradient
      // shows in its place.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.byKey(const ValueKey('profile-picture')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('card-picture-fallback')),
        findsOneWidget,
      );
      // The alias and "Edit chat profile" stay left of the painting.
      final cardRect = tester.getRect(card);
      final pictureStarts =
          cardRect.right -
          cardRect.width *
              ProfileCardLayout.pictureWidth *
              (1 - CardPicture.clearUntil);
      for (final text in ['Soft Owl', 'Edit chat profile']) {
        expect(
          tester.getRect(find.text(text)).right,
          lessThanOrEqualTo(pictureStarts + 0.5),
          reason: text,
        );
      }
      expect(find.byIcon(AppIcons.edit), findsOneWidget); // pencil
    });

    testWidgets('"Open to chat" is off by default', (tester) async {
      expect(const ChatProfile(alias: 'A', avatarId: 'cat_01').open, isFalse);
      await _pumpMe(tester);
      final toggle = tester.widget<LoomaSwitch>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Open to chat'),
            matching: find.byType(GroupedRow),
          ),
          matching: find.byType(LoomaSwitch),
        ),
      );
      expect(toggle.value, isFalse);
    });
  });
}
