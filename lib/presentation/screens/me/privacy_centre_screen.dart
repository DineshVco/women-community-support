import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/content_width.dart';
import '../../widgets/looma_button.dart';

/// Plain words on who can see what, and "Delete my account and data".
class PrivacyCentreScreen extends StatefulWidget {
  const PrivacyCentreScreen({super.key});

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
      'Dark mode, Gentle mode, Reduce motion and the first-post hearts. '
          'These never leave your phone.',
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete your account?',
      message:
          'This deletes your posts, replies, saved posts, chat profile and '
          'private profile, then your login. It cannot be undone.',
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
      await posts.deleteLogin();
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

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirm it is you'),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Your password'),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.of(dialogContext).pop(controller.text),
                child: const Text('Continue'),
              ),
            ],
          ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final email = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy centre')),
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
                Container(
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
                        'Deletes your posts, replies, saved posts, chat '
                        'profile and private profile, then your login. '
                        '"Me too" taps and reports you made stay, with '
                        'nothing that links them to you.',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
