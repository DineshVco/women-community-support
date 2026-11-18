import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
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

/// Long-press a post in the feed: an iOS context menu with Save, Share and
/// Report. A normal tap still opens the post.
class PostContextMenu extends StatelessWidget {
  const PostContextMenu({super.key, required this.post, required this.child});

  final Post post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoContextMenu.builder(
      enableHapticFeedback: true,
      actions: [
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.bookmark,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            PostActions.toggleSaved(context, post);
          },
          child: const Text('Save'),
        ),
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.square_on_square,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            PostActions.share(context, post);
          },
          child: const Text('Share'),
        ),
        CupertinoContextMenuAction(
          isDestructiveAction: true,
          trailingIcon: CupertinoIcons.flag,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            PostActions.report(context, post);
          },
          child: const Text('Report'),
        ),
      ],
      builder: (context, animation) {
        // While held, the post lifts onto a rounded card.
        final t = CupertinoContextMenu.animationOpensAt;
        final lifted = (animation.value / t).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(palette.background, palette.surface, lifted),
            borderRadius: BorderRadius.circular(20 * lifted),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20 * lifted),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        );
      },
    );
  }
}
