import 'dart:ui' show SemanticsFlag;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:women_community_support/core/constants/daily_questions.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/data/help_lines.dart';
import 'package:women_community_support/data/models/category.dart';
import 'package:women_community_support/data/models/community.dart';
import 'package:women_community_support/data/models/post.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/presentation/screens/create_post_screen.dart';
import 'package:women_community_support/presentation/screens/moderator_screen.dart';
import 'package:women_community_support/presentation/widgets/community_cards.dart';
import 'package:women_community_support/presentation/widgets/poll_view.dart';
import 'package:women_community_support/presentation/widgets/question_of_the_day.dart';

/// The real content files, as the app loads them at start-up.
final ContentLibrary _library = ContentLibrary.parse(
  guidesJson: File('content/guides.json').readAsStringSync(),
  directoryJson: File('content/directory.json').readAsStringSync(),
  dailyQuestionsJson: File('content/daily_questions.json').readAsStringSync(),
  smallWinsJson: File('content/small_wins.json').readAsStringSync(),
);

Widget _app(Widget child, {ThemeData? theme, bool reduceMotion = false}) =>
    ContentScope(
      library: _library,
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
        home: Scaffold(body: ListView(children: [child])),
      ),
    );

const _options = ['Yes, often', 'Sometimes', 'Rarely', 'No'];

void main() {
  // ───────────────────────── Polls ─────────────────────────

  group('Poll', () {
    testWidgets('before voting: answers to tap, no results shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PollView(
            options: _options,
            counts: const [3, 1, 0, 0],
            voted: false,
            onVote: (_) async {},
          ),
        ),
      );
      for (final o in _options) {
        expect(find.text(o), findsOneWidget);
      }
      expect(find.text(PollView.hint), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('4 votes'), findsNothing);
    });

    testWidgets('tapping an answer votes once for that answer', (tester) async {
      final votes = <int>[];
      var voted = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder:
              (context, setState) => _app(
                PollView(
                  options: _options,
                  counts: voted ? const [3, 2, 0, 0] : const [3, 1, 0, 0],
                  voted: voted,
                  onVote: (option) async {
                    votes.add(option);
                    setState(() => voted = true);
                  },
                ),
              ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Vote: Sometimes'));
      await tester.pumpAndSettle();

      expect(votes, [1]);
      // Results now: 3 of 5 and 2 of 5, her answer ticked.
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('0%'), findsNWidgets(2));
      expect(find.text('5 votes'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sometimes, 40%, your vote'),
        findsOneWidget,
      );
      // No more answer buttons: one vote, final.
      expect(find.bySemanticsLabel(RegExp('^Vote: ')), findsNothing);
    });

    testWidgets('after voting (e.g. on another day): results straight away', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PollView(
            options: const ['Yes', 'No'],
            counts: const [1, 0],
            voted: true,
            onVote: (_) async => fail('must not vote again'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 vote'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
    });

    testWidgets('a failed vote says so and lets her try again', (tester) async {
      await tester.pumpWidget(
        _app(
          PollView(
            options: const ['Yes', 'No'],
            counts: const [0, 0],
            voted: false,
            onVote: (_) async => throw StateError('offline'),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Vote: No'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Could not save your vote. Please try again.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Vote: No'), findsOneWidget);
    });

    testWidgets('waiting for her vote state: answers cannot be tapped yet', (
      tester,
    ) async {
      final votes = <int>[];
      await tester.pumpWidget(
        _app(
          PollView(
            options: const ['Yes', 'No'],
            counts: const [0, 0],
            voted: null,
            onVote: (o) async => votes.add(o),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Vote: Yes'));
      await tester.pump();
      expect(votes, isEmpty);
    });

    testWidgets('Reduce motion: the bars appear without animating', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PollView(
            options: const ['Yes', 'No'],
            counts: const [1, 1],
            voted: true,
            onVote: (_) async {},
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      // Already at the end: no frames left to run.
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('50%'), findsNWidgets(2));
    });

    testWidgets('looks right in dark mode', (tester) async {
      await tester.pumpWidget(
        _app(
          PollView(
            options: _options,
            counts: const [1, 2, 3, 4],
            voted: true,
            onVote: (_) async {},
          ),
          theme: AppTheme.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('40%'), findsOneWidget);
    });

    test('a poll post is read from Firestore data', () {
      final post = Post.fromMap('p1', {
        'alias': 'Looma Team',
        'categoryId': 'health_wellness',
        'title': 'Do you feel guilty when you rest?',
        'content': '',
        'type': 'poll',
        'options': ['Yes', 'No'],
        'voteCounts': [2, 3],
      });
      expect(post.isPoll, isTrue);
      expect(post.options, ['Yes', 'No']);
      expect(post.voteCounts, [2, 3]);
      expect(post.totalVotes, 5);
      expect(
        Post.fromMap('p2', {'title': 'Hello', 'content': 'Hi'}).isPoll,
        isFalse,
      );
    });

    test('the "Me too" key matches the rules, and differs per post', () {
      // python: hashlib.sha256(b'looma-metoo:poll1:siti').hexdigest()
      expect(
        PostRepository.reactionKeyFor('siti', 'poll1'),
        'ebc74ae133c27fae4cfd077292ba57aaa5ba6f6b65c4e8c2f92e7f6c12aa84e5',
      );
      expect(
        PostRepository.reactionKeyFor('siti', 'poll2'),
        isNot(PostRepository.reactionKeyFor('siti', 'poll1')),
      );
      // Never the uid itself.
      expect(PostRepository.reactionKeyFor('siti', 'poll1'), isNot('siti'));
    });

    test('the vote key matches the one the rules compute', () {
      // node -e "crypto.createHash('sha256').update('looma-vote:poll1:siti')"
      expect(
        PostRepository.voteKeyFor('siti', 'poll1'),
        '3ed4b7343945de495422425b68d8f53a3598c293675a675a590ab77a0baff0e1',
      );
      // Different for each poll, so votes cannot be matched across polls.
      expect(
        PostRepository.voteKeyFor('siti', 'poll2'),
        isNot(PostRepository.voteKeyFor('siti', 'poll1')),
      );
    });
  });

  // ───────────────────────── New poll ─────────────────────────

  group('New poll', () {
    Future<void> openPoll(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const CreatePostScreen(startAsPoll: true),
        ),
      );
    }

    testWidgets('2 answers to start, up to 4, and back down to 2', (
      tester,
    ) async {
      await openPoll(tester);
      expect(find.text('New poll'), findsOneWidget);
      expect(find.text(CreatePostScreen.pollNote), findsOneWidget);
      expect(find.text('Answer 1'), findsOneWidget);
      expect(find.text('Answer 2'), findsOneWidget);
      expect(find.text('Answer 3'), findsNothing);

      await tester.tap(find.text('Add an answer'));
      await tester.pump();
      await tester.tap(find.text('Add an answer'));
      await tester.pump();
      expect(find.text('Answer 4'), findsOneWidget);
      expect(find.text('Add an answer'), findsNothing);

      await tester.tap(find.byTooltip('Remove answer 4'));
      await tester.pump();
      await tester.tap(find.byTooltip('Remove answer 3'));
      await tester.pump();
      expect(find.text('Answer 3'), findsNothing);
      expect(find.byTooltip('Remove answer 1'), findsNothing);
    });

    testWidgets('needs a question and 2 different answers', (tester) async {
      await openPoll(tester);
      await tester.tap(find.text('Health & Wellness'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Question'),
        'Do you rest enough?',
      );
      await tester.enterText(
        find.byKey(const ValueKey('poll-option-0')),
        'Yes',
      );
      await tester.tap(find.text('Post').last); // the Post button
      await tester.pump();
      expect(find.text('Add at least 2 answers.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('poll-option-1')),
        'Yes',
      );
      await tester.tap(find.text('Post').last);
      await tester.pump();
      expect(find.text('Each answer must be different.'), findsOneWidget);
    });

    testWidgets('switching back to Post asks for the story again', (
      tester,
    ) async {
      await openPoll(tester);
      await tester.tap(find.text('Post').first); // the Post/Poll switch
      await tester.pump();
      expect(find.text('New post'), findsOneWidget);
      expect(find.text('Answer 1'), findsNothing);
      expect(find.text('Your story or question'), findsOneWidget);
    });
  });

  // ───────────────────────── Daily question ─────────────────────────

  testWidgets('Home shows today\'s question from daily_questions.json', (
    tester,
  ) async {
    String? answered;
    await tester.pumpWidget(
      _app(QuestionOfTheDay(onAnswer: (q) => answered = q)),
    );
    final today =
        DailyQuestions.forDate(_library.dailyQuestions, DateTime.now())!;
    expect(_library.dailyQuestions, hasLength(30));
    expect(find.text(today), findsOneWidget);
    await tester.tap(find.text('Share your answer'));
    expect(answered, today);
  });

  // ───────────────────────── Small wins ─────────────────────────

  group('Small wins', () {
    final thread = SmallWinsThread(
      id: 'w1',
      title: 'Friday small wins: share one thing you are proud of.',
      startsAt: DateTime(2026, 11, 13),
      endsAt: DateTime(2026, 11, 20),
    );

    testWidgets('pinned card: gentle line, no counts, opens the thread', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        _app(SmallWinsCard(thread: thread, onOpen: () => opened++)),
      );
      expect(find.text('SMALL WINS · THIS WEEK'), findsOneWidget);
      expect(find.text(thread.title), findsOneWidget);
      expect(find.text(SmallWinsCard.line), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\d+ (likes?|replies|me too)')),
        findsNothing,
      );
      await tester.tap(find.text('Share a small win'));
      expect(opened, 1);
    });

    test('active only between its start and end', () {
      expect(thread.isActive(DateTime(2026, 11, 15)), isTrue);
      expect(thread.isActive(DateTime(2026, 11, 20)), isFalse);
      expect(thread.isActive(DateTime(2026, 11, 12)), isFalse);
      expect(SmallWinsThread.fromMap('x', {'kind': 'other'}), isNull);
    });

    test('the prompt comes from small_wins.json and changes weekly', () {
      final prompts = _library.smallWinsPrompts;
      expect(prompts, hasLength(6));
      final a = ModeratorScreen.smallWinsPromptFor(
        prompts,
        DateTime(2026, 11, 16),
      );
      final sameWeek = ModeratorScreen.smallWinsPromptFor(
        prompts,
        DateTime(2026, 11, 22),
      );
      final next = ModeratorScreen.smallWinsPromptFor(
        prompts,
        DateTime(2026, 11, 23),
      );
      expect(prompts, contains(a));
      expect(sameWeek, a);
      expect(next, isNot(a));
      for (final p in prompts) {
        expect(p.length, inInclusiveRange(3, 120), reason: p);
      }
    });
  });

  // ───────────────────────── Themed weeks ─────────────────────────

  group('Themed week', () {
    final week =
        ThemedWeek.fromMap({
          'title': 'Study week',
          'subtitle': 'Small steps for exam season.',
          'colorKey': 'sage',
          'guideIds': ['exam-stress', 'group-work', 'no-such-guide'],
          'startsAt': Timestamp.fromDate(DateTime(2026, 11, 16)),
          'endsAt': Timestamp.fromDate(DateTime(2026, 11, 23)),
        })!;

    testWidgets('banner shows the week and lists its guides', (tester) async {
      await tester.pumpWidget(_app(ThemedWeekBanner(week: week)));
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('Study week'), findsOneWidget);
      expect(find.text('Small steps for exam season.'), findsOneWidget);

      await tester.tap(find.text('Study week'));
      await tester.pumpAndSettle();
      expect(find.text('Guides for this week'), findsOneWidget);
      expect(find.text('Exam stress: small steps that help'), findsOneWidget);
      expect(find.text('When you do all the group work'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    test('active only during its dates', () {
      expect(week.isActive(DateTime(2026, 11, 19)), isTrue);
      expect(week.isActive(DateTime(2026, 11, 23)), isFalse);
      expect(ThemedWeek.fromMap({'title': ''}), isNull);
    });
  });

  // ───────────────────────── Ask Looma ─────────────────────────

  testWidgets('Ask Looma: opens compose in its category with a note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const CreatePostScreen(
          initialCategoryId: AppCategories.askLoomaId,
        ),
      ),
    );
    expect(find.text(CreatePostScreen.askNote), findsOneWidget);
    // Its chip is already chosen.
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Ask Looma Team'))
          .hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
  });
}
