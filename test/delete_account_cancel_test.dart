import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:women_community_support/core/security/secure_store.dart';
import 'package:women_community_support/core/theme/app_theme.dart';
import 'package:women_community_support/data/auth/sign_in_cancel.dart';
import 'package:women_community_support/data/content_library.dart';
import 'package:women_community_support/data/journal.dart';
import 'package:women_community_support/data/local_private_data.dart';
import 'package:women_community_support/data/mood.dart';
import 'package:women_community_support/data/repositories/chat_repository.dart';
import 'package:women_community_support/data/repositories/post_repository.dart';
import 'package:women_community_support/data/safety_plan.dart';
import 'package:women_community_support/presentation/screens/me/privacy_centre_screen.dart';

class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _NoAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

/// Signed in with Google; the "confirm it is you" step waits for the test.
class _Posts extends PostRepository {
  _Posts() : super(firestore: _NoDb(), auth: _NoAuth());

  int confirms = 0;
  int deletes = 0;
  Completer<bool> pending = Completer<bool>();

  @override
  SignInMethod get signInMethod => SignInMethod.google;

  @override
  Future<Duration> waitBeforeAccountDeletion() async => Duration.zero;

  @override
  Future<bool> reauthenticate({String? password}) {
    confirms++;
    pending = Completer<bool>();
    return pending.future;
  }

  @override
  Future<void> deleteMyContent() async => deletes++;
}

class _Chat extends ChatRepository {
  _Chat() : super(firestore: _NoDb(), auth: _NoAuth());
}

final _delete = find.text('Delete my account');
// While it waits for Google, the button shows its spinner.
final _confirming = find.byKey(const ValueKey('loading'));

Future<_Posts> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final posts = _Posts();
  final secure = MemorySecureStore();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PostRepository>.value(value: posts),
        Provider<ChatRepository>.value(value: _Chat()),
        Provider<LocalPrivateData>.value(
          value: LocalPrivateData(
            moodLog: MoodStore(secure),
            journal: JournalStore(secure),
            safetyPlan: SafetyPlanStore(secure),
            guideBookmarks: GuideBookmarks(secure),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
        home: const PrivacyCentreScreen(deleteFirst: true),
      ),
    ),
  );
  await tester.pump();
  return posts;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps "Delete my account", then "Delete everything" in the dialog.
Future<void> _startDelete(WidgetTester tester) async {
  await tester.tap(_delete);
  await _settle(tester);
  await tester.tap(find.text('Delete everything'));
  await tester.pump();
}

void main() {
  group('Google confirm: cancel is a normal outcome', () {
    testWidgets('closed the window (not confirmed): back to normal, quietly', (
      tester,
    ) async {
      final posts = await _pump(tester);
      await _startDelete(tester);
      expect(_confirming, findsOneWidget); // a spinner while it waits
      posts.pending.complete(false);
      await _settle(tester);
      expect(_delete, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(posts.deletes, 0);
      // She can start again.
      await _startDelete(tester);
      expect(posts.confirms, 2);
      posts.pending.complete(false);
      await _settle(tester);
    });

    for (final (name, cancel) in <(String, Object)>[
      ('Android sign_in_canceled', PlatformException(code: 'sign_in_canceled')),
      (
        'web popup-closed-by-user',
        FirebaseAuthException(code: 'popup-closed-by-user'),
      ),
      (
        'web cancelled-popup-request',
        FirebaseAuthException(code: 'cancelled-popup-request'),
      ),
      ('web user-cancelled', FirebaseAuthException(code: 'user-cancelled')),
    ]) {
      testWidgets('$name: back to normal, no message', (tester) async {
        final posts = await _pump(tester);
        await _startDelete(tester);
        posts.pending.completeError(cancel);
        await _settle(tester);
        expect(_delete, findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(posts.deletes, 0);
      });
    }
  });

  testWidgets('an error shows a message and resets', (tester) async {
    final posts = await _pump(tester);
    await _startDelete(tester);
    posts.pending.completeError(
      FirebaseAuthException(code: 'network-request-failed'),
    );
    await _settle(tester);
    expect(_delete, findsOneWidget);
    expect(
      find.text('Could not confirm it is you. Please try again.'),
      findsOneWidget,
    );
    expect(posts.deletes, 0);
  });

  testWidgets('no answer for 60 seconds: resets with a short message', (
    tester,
  ) async {
    final posts = await _pump(tester);
    await _startDelete(tester);
    await tester.pump(const Duration(seconds: 59));
    expect(_confirming, findsOneWidget); // still waiting at 59 s
    await tester.pump(const Duration(seconds: 2));
    await _settle(tester);
    expect(_delete, findsOneWidget);
    expect(
      find.text(PrivacyCentreScreen.confirmTimeoutMessage),
      findsOneWidget,
    );
    expect(posts.deletes, 0);
    // A late answer does nothing.
    posts.pending.complete(true);
    await _settle(tester);
    expect(posts.deletes, 0);
  });

  testWidgets('a second tap is ignored', (tester) async {
    final posts = await _pump(tester);
    await tester.tap(_delete);
    await tester.tap(_delete, warnIfMissed: false); // same frame
    await _settle(tester);
    expect(find.text('Delete your account?'), findsOneWidget); // one dialog
    await tester.tap(find.text('Delete everything'));
    await tester.pump();
    await tester.tap(_confirming, warnIfMissed: false); // while waiting
    await tester.pump();
    expect(posts.confirms, 1);
    posts.pending.complete(false);
    await _settle(tester);
  });

  test('what counts as a cancel', () {
    expect(isSignInCancel(const SignInCancelled()), isTrue);
    expect(isSignInCancel(PlatformException(code: 'sign_in_canceled')), isTrue);
    expect(isSignInCancel(PlatformException(code: 'canceled')), isTrue);
    for (final code in webSignInCancelCodes) {
      expect(isSignInCancel(FirebaseAuthException(code: code)), isTrue);
    }
    expect(
      isSignInCancel(FirebaseAuthException(code: 'wrong-password')),
      isFalse,
    );
    expect(isSignInCancel(PlatformException(code: 'network_error')), isFalse);
  });
}
