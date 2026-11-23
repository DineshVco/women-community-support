import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/local_private_data.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/content_width.dart';
import '../../widgets/ios.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/quick_exit_button.dart';

/// Plain words on who can see what, and "Delete my account and data".
class PrivacyCentreScreen extends StatefulWidget {
  const PrivacyCentreScreen({super.key, this.deleteFirst = false});

  /// Opened from "Delete my account and data" on Me: the delete card is
  /// at the top (same confirmation as always).
  final bool deleteFirst;

  /// The confirmation before deleting everything.
  static const String deleteConfirmMessage =
      'This deletes your posts, replies, saved posts, chat profile and '
      'private profile, then your login. It also deletes your mood log, '
      'journal and safety plan from this phone. It cannot be undone.';

  /// When the phone's private data could not be deleted.
  static const String localDeleteFailedTitle =
      'Some private notes are still on this phone';
  static const String localDeleteFailedMessage =
      'Your posts, replies and online profile are deleted. But your mood '
      'log, journal or safety plan could not be removed from this phone. '
      'Your login is kept until they are, so nothing is left behind '
      'without you knowing. Try again?';

  /// The summary on the page, above the button.
  static const String deleteSummary =
      'Deletes your posts, replies, saved posts, chat profile and private '
      'profile, then your login. Your mood log, journal and safety plan are '
      'deleted from this phone too. "Me too" taps and reports you made stay, '
      'with nothing that links them to you.';

  /// The text blocks, kept here so a test can check the honest parts.
  static const List<(String, String)> sections = [
    (
      'What other women can see',
      'In Discuss: your posts and replies, under a random alias that changes '
          'in every discussion.\n'
          'In Connect, only while "Open to chat" is on: your chat alias, '
          'avatar, interests, what you are looking for and your bio.\n'
          'Never: your name, email, birth year, or which posts are yours. '
          'Your chat profile is kept separate, so nobody can link it to your '
          'posts.',
    ),
    (
      'What moderators can see',
      'Posts and replies that someone reported, so they can decide what to '
          'do. They never see who wrote them.',
    ),
    (
      'What the project owner can see',
      'To be honest about the limits: the person who runs Looma\'s database '
          'can technically see everything stored in it. That includes your '
          'email, your birth year, which posts and replies are yours, your '
          'saved posts and your chat profile. Avoid sharing names, places or '
          'details that could identify you or others.',
    ),
    (
      '"Women only"',
      'Everyone confirms they are a woman when they join. Looma cannot '
          'prove it, so stay careful, especially in private chats.',
    ),
    (
      'Kept only on this phone',
      'Your mood log, journal and safety plan (encrypted), and settings like '
          'Dark mode, Gentle mode and Reduce motion. These never leave your '
          'phone.',
    ),
    (
      'The Weather disguise',
      'To show a real forecast, the Weather disguise sends the city you '
          'chose to Open-Meteo, a free weather service (first the city name, '
          "then that city's place on the map). Nothing else: not your "
          'account, your posts or anything you wrote. Like any website, '
          "Open-Meteo can see your phone's internet address.",
    ),
  ];

  @override
  State<PrivacyCentreScreen> createState() => _PrivacyCentreScreenState();
}

class _PrivacyCentreScreenState extends State<PrivacyCentreScreen> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    final posts = context.read<PostRepository>();
    final chat = context.read<ChatRepository>();
    final local = context.read<LocalPrivateData>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Rules: no deleting within a minute of posting (stops the post limit
    // being dodged by deleting and re-creating the account record).
    try {
      final wait = await posts.waitBeforeAccountDeletion();
      if (wait > Duration.zero) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'You posted less than a minute ago. Please wait '
              '${wait.inSeconds + 1} seconds, then try again.',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Could not check (offline?): the delete below will say so.
    }
    if (!mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete your account?',
      message: PrivacyCentreScreen.deleteConfirmMessage,
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    // Firebase needs a recent sign-in before it deletes a login.
    try {
      final bool ok;
      if (posts.signInMethod == SignInMethod.password) {
        final password = await _askPassword();
        if (password == null) return;
        ok = await posts.reauthenticate(password: password);
      } else {
        ok = await posts.reauthenticate();
      }
      if (!ok) return;
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'wrong-password' || e.code == 'invalid-credential'
                ? 'That password is not right.'
                : 'Could not confirm it is you. Please try again.',
          ),
        ),
      );
      return;
    }

    setState(() => _deleting = true);
    try {
      await chat.deleteMine();
      await posts.deleteMyContent();
      // Also on this phone: mood log, journal and safety plan. Only when
      // that worked is the login deleted.
      final outcome = await AccountDeletion.finish(
        deleteLocal: local.deleteAll,
        deleteLogin: posts.deleteLogin,
        askRetry: _askRetryLocalDelete,
      );
      if (outcome == DeletionOutcome.loginKept) {
        if (!mounted) return;
        setState(() => _deleting = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Your account is kept until the private notes on this phone '
              'are deleted. Open "Delete my account" again to finish.',
            ),
          ),
        );
        return;
      }
      // Signed out now: go back to the start (the sign-in screens).
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete everything. Check your connection and try '
            'again; it continues where it stopped.',
          ),
        ),
      );
    }
  }

  /// Her email for the "Signed in as" line; nothing if it cannot be read.
  static String? _signedInEmail() {
    try {
      return FirebaseAuth.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Said plainly when the phone's private data could not be deleted.
  Future<bool> _askRetryLocalDelete() async {
    if (!mounted) return false;
    return showConfirmDialog(
      context,
      title: PrivacyCentreScreen.localDeleteFailedTitle,
      message: PrivacyCentreScreen.localDeleteFailedMessage,
      confirmLabel: 'Try again',
      cancelLabel: 'Not now',
    );
  }

  Future<String?> _askPassword() => showTextDialog(
    context,
    title: 'Confirm it is you',
    message: 'Type your password to delete your account.',
    placeholder: 'Password',
    confirmLabel: 'Continue',
    obscure: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final email = _signedInEmail();

    final deleteCard = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete my account and data',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            PrivacyCentreScreen.deleteSummary,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          LoomaButton.outline(
            label: _deleting ? 'Deleting…' : 'Delete my account',
            loading: _deleting,
            onPressed: _deleteAccount,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: loomaNavBar(context, title: 'Privacy centre'),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: AbsorbPointer(
            absorbing: _deleting,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              children: [
                if (widget.deleteFirst) ...[
                  deleteCard,
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (email != null) ...[
                  Text(
                    'Signed in as $email',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Only you see this. Your email is used to sign in and is '
                    'never shown next to anything you write.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                for (final (title, body) in PrivacyCentreScreen.sections) ...[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text('Quick exit', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tap Quick exit at the top of any page and Looma is '
                  'replaced by a weather screen straight away. To come back, '
                  'press and hold anywhere for 1 second, or tap the '
                  'temperature 3 times. With the calculator, type your PIN '
                  'and press =.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                LoomaButton.outline(
                  label: 'Practice Quick exit',
                  onPressed: () => QuickExit.practice(context),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!widget.deleteFirst) deleteCard,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
