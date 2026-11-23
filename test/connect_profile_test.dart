import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/core/utils/content_filter.dart';
import 'package:women_community_support/data/models/chat_profile.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/data/repositories/chat_repository.dart';
import 'package:women_community_support/presentation/providers/app_settings.dart';
import 'package:women_community_support/presentation/providers/theme_provider.dart';
import 'package:women_community_support/presentation/screens/me/chat_profile_editor.dart';
import 'package:women_community_support/presentation/screens/me/open_to_chat_tile.dart';
import 'package:women_community_support/presentation/screens/me/privacy_centre_screen.dart';
import 'package:women_community_support/presentation/widgets/cat_avatar.dart';
import 'package:women_community_support/presentation/widgets/post_card.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  // ───────────────────────── Chat id ─────────────────────────

  group('chat profile id', () {
    test('is a sha256 hash, never the uid (same value as the rules)', () {
      // Python: hashlib.sha256(b'looma-chat:amira').hexdigest()
      expect(
        ChatRepository.chatIdFor('amira'),
        'fa6aa34aaf657b3d3c33a9c7a486b297f21af7c4e6af20e38bb77663e7d5f01e',
      );
      expect(ChatRepository.chatIdFor('amira'), isNot(contains('amira')));
    });
  });

  // ───────────────────────── Filters ─────────────────────────

  group('ContactFilter (same cases as the rules tests)', () {
    test('finds links, emails, handles and phone numbers', () {
      for (final text in [
        'see https://example.org',
        'visit WWW.mypage.net',
        'find me at mypage.com!',
        'my site is mypage.my',
        'email amira@mail.com',
        'IG @amira_x',
        'whatsapp 012-345 6789',
        'call +60 12 345 6789',
      ]) {
        expect(
          ContactFilter.containsContactDetails(text),
          isTrue,
          reason: text,
        );
      }
    });

    test('leaves ordinary sentences alone', () {
      for (final text in [
        '',
        'Class of 2020-2024. I love cats.',
        'Studying at uni, @ home most days',
        'I like co-op games and mysteries.',
      ]) {
        expect(
          ContactFilter.containsContactDetails(text),
          isFalse,
          reason: text,
        );
      }
    });
  });

  group('chat alias check', () {
    String? check(String alias, {String? email, String? name}) =>
        ChatProfileChecks.alias(alias, email: email, displayName: name);

    test('accepts nicknames', () {
      for (final alias in [
        'moonreader',
        'calm_kitten',
        'night owl 22',
        'Ayu',
      ]) {
        expect(check(alias), isNull, reason: alias);
      }
    });

    test('length and characters', () {
      expect(check('ab'), isNotNull);
      expect(check('a' * 21), isNotNull);
      expect(check('<moon>'), isNotNull);
    });

    test('no contact details or phone numbers', () {
      expect(check('call 0123456789'), ContactFilter.kindMessage);
    });

    test('no real-name patterns', () {
      expect(check('Siti Aminah'), contains('real name'));
      // Looks like a post alias too: never reused for chat.
      expect(check('Quiet Fern'), contains('real name'));
    });

    test('not her own name or email name', () {
      expect(
        check('nurulreads', email: 'nurul.huda@mail.com'),
        contains('real name or email'),
      );
      expect(
        check('the_amira', name: 'Amira Rahman'),
        contains('real name or email'),
      );
    });

    test('bio: 120 characters, no contact details', () {
      expect(ChatProfileChecks.bio('x' * 121), isNotNull);
      expect(ChatProfileChecks.bio('dm me @amira'), ContactFilter.kindMessage);
      expect(ChatProfileChecks.bio('Nursing student who loves cats.'), isNull);
    });
  });

  // ───────────────────────── Avatars ─────────────────────────

  testWidgets('12 cat avatars, all draw without errors', (tester) async {
    expect(CatAvatars.ids, hasLength(12));
    await tester.pumpWidget(
      _app(
        Wrap(children: [for (final id in CatAvatars.ids) CatAvatar(id: id)]),
      ),
    );
    expect(find.byType(CatAvatar), findsNWidgets(12));
    expect(find.bySemanticsLabel('Cat avatar 12'), findsOneWidget);
  });

  // ───────────────────────── Editor ─────────────────────────

  group('ChatProfileEditor', () {
    Future<List<ChatProfileDraft>> pumpEditor(
      WidgetTester tester, {
      ChatProfile? initial,
    }) async {
      // A tall phone, so the whole form is built (ListView is lazy).
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final saved = <ChatProfileDraft>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChatProfileEditor(
            initial: initial,
            email: 'nurul.huda@mail.com',
            onSave: (draft) async => saved.add(draft),
          ),
        ),
      );
      return saved;
    }

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
    }

    testWidgets('refuses a real name and does not save', (tester) async {
      final saved = await pumpEditor(tester);
      await tester.enterText(find.byType(TextField).first, 'Nurul Huda');
      await tapSave(tester);

      expect(saved, isEmpty);
      expect(
        find.text('Please do not use your real name or email in your alias.'),
        findsOneWidget,
      );
    });

    testWidgets('refuses contact details in the bio', (tester) async {
      final saved = await pumpEditor(tester);
      await tester.enterText(find.byType(TextField).first, 'moonreader');
      await tester.enterText(find.byType(TextField).last, 'text me 0123456789');
      await tapSave(tester);

      expect(saved, isEmpty);
      expect(find.text(ContactFilter.kindMessage), findsOneWidget);
    });

    testWidgets('saves avatar, alias, bio, interests and looking for', (
      tester,
    ) async {
      final saved = await pumpEditor(tester);
      await tester.tap(find.bySemanticsLabel('Cat avatar 5'));
      await tester.enterText(find.byType(TextField).first, '  moonreader ');
      await tester.enterText(find.byType(TextField).last, 'I love cats.');
      for (final label in ['Study', 'Mental wellbeing', 'Study buddy']) {
        final chip = find.widgetWithText(FilterChip, label);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
      }
      await tapSave(tester);

      expect(saved, hasLength(1));
      final draft = saved.single;
      expect(draft.alias, 'moonreader');
      expect(draft.avatarId, 'cat_05');
      expect(draft.bio, 'I love cats.');
      expect(draft.interests, ['study', 'mental_wellbeing']);
      expect(draft.lookingFor, ['study_buddy']);
    });

    testWidgets('at most 5 interests: the rest are disabled', (tester) async {
      await pumpEditor(
        tester,
        initial: const ChatProfile(
          alias: 'moonreader',
          avatarId: 'cat_01',
          interests: ['health', 'study', 'career', 'safety', 'family'],
        ),
      );
      final money = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Money'),
      );
      expect(money.onSelected, isNull);
      final health = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Health'),
      );
      expect(health.onSelected, isNotNull);
    });
  });

  // ───────────────────────── Open to chat ─────────────────────────

  group('OpenToChatTile', () {
    final now = DateTime(2026, 11, 18, 12);
    const profile = ChatProfile(alias: 'moonreader', avatarId: 'cat_01');

    Future<CupertinoSwitch> pumpTile(
      WidgetTester tester, {
      ChatProfile? profile,
      DateTime? joinedAt,
    }) async {
      await tester.pumpWidget(
        _app(
          OpenToChatTile(
            profile: profile,
            joinedAt: joinedAt,
            now: now,
            onChanged: (_) {},
          ),
        ),
      );
      return tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    }

    testWidgets('promises nothing before Connect exists', (tester) async {
      await pumpTile(tester, profile: profile);
      expect(
        find.textContaining(
          'When Connect arrives, other women will see your chat alias and '
          'avatar, never your posts.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('can see your alias'), findsNothing);
    });

    testWidgets('off without a chat profile', (tester) async {
      final tile = await pumpTile(tester, joinedAt: DateTime(2020));
      expect(tile.onChanged, isNull);
      expect(
        find.textContaining('Set up your chat profile first.'),
        findsOneWidget,
      );
    });

    testWidgets('waits 24 hours after sign-up', (tester) async {
      final tile = await pumpTile(
        tester,
        profile: profile,
        joinedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(tile.onChanged, isNull);
      expect(find.textContaining('in about 22 hours'), findsOneWidget);
    });

    testWidgets('can be turned on after a day', (tester) async {
      final tile = await pumpTile(
        tester,
        profile: profile,
        joinedAt: now.subtract(const Duration(days: 2)),
      );
      expect(tile.onChanged, isNotNull);
    });

    testWidgets('can always be turned off', (tester) async {
      final tile = await pumpTile(
        tester,
        profile: profile.copyWith(open: true),
        joinedAt: null,
      );
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
    });
  });

  // ───────────────────────── Settings ─────────────────────────

  group('settings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Gentle mode and Reduce motion are remembered on the phone', () async {
      final settings = await AppSettings.load();
      expect(settings.gentleMode, isFalse);
      await settings.setGentleMode(true);
      await settings.setReduceMotion(true);

      final again = await AppSettings.load();
      expect(again.gentleMode, isTrue);
      expect(again.reduceMotion, isTrue);
    });

    test('dark mode choice is remembered', () async {
      final theme = await ThemeProvider.load();
      expect(theme.themeMode, ThemeMode.system);
      theme.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect((await ThemeProvider.load()).themeMode, ThemeMode.dark);
    });

    testWidgets('Gentle mode hides the counts on a post', (tester) async {
      final post = Post(
        id: 'p1',
        alias: 'Quiet Fox',
        categoryId: 'education',
        title: 'Scholarship tips?',
        content: 'Any advice?',
        timestamp: DateTime.now(),
        meTooCount: 4,
        commentCount: 3,
      );

      await tester.pumpWidget(_app(PostCard(post: post)));
      expect(find.bySemanticsLabel('4 me too'), findsOneWidget);
      expect(find.bySemanticsLabel('3 replies'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          AppSettingsScope(
            settings: AppSettings(gentleMode: true),
            child: PostCard(post: post),
          ),
        ),
      );
      expect(find.bySemanticsLabel('4 me too'), findsNothing);
      expect(find.bySemanticsLabel('3 replies'), findsNothing);
      expect(find.text('Scholarship tips?'), findsOneWidget);
    });
  });

  // ───────────────────────── Privacy centre ─────────────────────────

  test('privacy centre is honest about its limits', () {
    final all = PrivacyCentreScreen.sections.map((s) => s.$2).join('\n');
    expect(all, contains('can technically see everything'));
    expect(all, contains('cannot prove it'));
    expect(all, contains('nobody can link it to your posts'));
  });
}
