import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/haptics.dart';
import '../../data/models/post.dart';
import '../../data/models/report.dart';
import '../../data/repositories/post_repository.dart';
import 'adaptive.dart';

/// Actions on a post, shared by the post page and the long-press menu in
/// the feed. Same behaviour in both places.
class PostActions {
  PostActions._();

  static void _say(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Report: one private report per person per post.
  static Future<void> report(BuildContext context, Post post) async {
    final repo = context.read<PostRepository>();
    if (await repo.hasReported(post.id)) {
      if (context.mounted) {
        _say(
          context,
          'You already reported this post. You can see what happened to it '
          'under Me.',
        );
      }
      return;
    }
    if (!context.mounted) return;

    final reason = await showOptionsSheet<String>(
      context,
      title: 'Report this post',
      message:
          'Your report is private. The author is not told who reported it.',
      options: [
        for (final reason in ReportReasons.all)
          SheetOption(value: reason, label: reason),
      ],
    );
    if (reason == null || !context.mounted) return;

    try {
      await repo.reportPost(post: post, reason: reason);
      AppHaptics.medium();
      if (context.mounted) {
        _say(
          context,
          'Thank you. A moderator will review it. You can follow the outcome '
          'under Me.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _say(context, 'Could not send the report. Please try again.');
      }
    }
  }

  /// Save or un-save (private bookmark).
  static Future<void> toggleSaved(BuildContext context, Post post) async {
    final repo = context.read<PostRepository>();
    try {
      final saved = await repo.watchSaved(post.id).first;
      await repo.setSaved(post.id, saved: !saved);
      AppHaptics.light();
      if (context.mounted) {
        _say(
          context,
          saved ? 'Removed from saved' : 'Saved. Find it under Me.',
        );
      }
    } catch (_) {
      if (context.mounted) _say(context, 'Could not update your saved posts.');
    }
  }

  /// Share: copies the post's title and text (never the alias) so she can
  /// paste it into any app. (A system share sheet needs an extra package.)
  static Future<void> share(BuildContext context, Post post) async {
    await Clipboard.setData(
      ClipboardData(text: '${post.title}\n\n${post.content}'),
    );
    AppHaptics.light();
    if (context.mounted) {
      _say(context, 'Copied. Paste it into any app to share.');
    }
  }
}

enum _PostAction { save, share, report }

/// Long-press a post in the feed: an iOS action sheet with Save, Share and
/// Report. A normal tap still opens the post.
///
/// Not a CupertinoContextMenu on purpose: that widget floats a copy of the
/// post over the whole app while the finger rests on it, and if the post
/// is scrolled out of the list before the copy shrinks back, Flutter never
/// removes the copy. Each leftover copy is invisible glass that swallows
/// touches, so after a few quick scrolls the feed could not be scrolled any
/// more. A plain long press draws nothing over the app, and it gives way to
/// scrolling as soon as the finger moves.
class PostContextMenu extends StatelessWidget {
  const PostContextMenu({super.key, required this.post, required this.child});

  final Post post;
  final Widget child;

  Future<void> _open(BuildContext context) async {
    AppHaptics.medium();
    final action = await showOptionsSheet<_PostAction>(
      context,
      title: post.title,
      options: const [
        SheetOption(value: _PostAction.save, label: 'Save'),
        SheetOption(value: _PostAction.share, label: 'Share'),
        SheetOption(
          value: _PostAction.report,
          label: 'Report',
          isDestructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _PostAction.save:
        await PostActions.toggleSaved(context, post);
      case _PostAction.share:
        await PostActions.share(context, post);
      case _PostAction.report:
        await PostActions.report(context, post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Save, share or report'):
            () => _open(context),
      },
      child: GestureDetector(onLongPress: () => _open(context), child: child),
    );
  }
}
