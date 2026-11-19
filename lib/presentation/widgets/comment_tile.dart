import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/comment.dart';
import 'team_badge.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.isAuthor,
    this.isReply = false,
    this.onReply,
  });

  final Comment comment;

  /// True when this comment was written by the person who started the post.
  final bool isAuthor;
  final bool isReply;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                comment.alias,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (LoomaTeam.isTeam(comment.alias)) ...[
              const SizedBox(width: AppSpacing.sm),
              const TeamBadge(),
            ],
            if (isAuthor) ...[
              const SizedBox(width: AppSpacing.sm),
              // Small black tag for the person who started the discussion.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(AppRadius.tag),
                ),
                child: Text(
                  'Original poster',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.onPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            Text(timeAgo(comment.timestamp), style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(comment.content, style: theme.textTheme.bodyLarge),
        if (onReply != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onReply,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                minimumSize: const Size(48, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reply'),
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal + (isReply ? AppSpacing.xl : 0),
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      child:
          isReply
              ? Container(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: palette.border, width: 2),
                  ),
                ),
                child: body,
              )
              : body,
    );
  }
}
