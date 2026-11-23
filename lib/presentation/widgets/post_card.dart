import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/post.dart';
import '../providers/app_settings.dart';
import 'category_label.dart';
import 'poll_view.dart';
import 'post_title_hero.dart';
import 'team_badge.dart';

/// One row in the feed. Plain: no card, no shadow, separated by 1 px lines.
///  CATEGORY
///  Title (Newsreader 22)
///  Two lines of preview in grey
///  Quiet Fox · 2 h ago                    4 me too   3 replies
/// Gentle mode hides the two numbers.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final small = theme.textTheme.bodySmall;
    final gentle = AppSettings.gentleOf(context);
    final team = LoomaTeam.isTeam(post.alias);
    final aliasLine = AliasLine(
      alias: post.alias,
      text: post.alias,
      trailing: ' · ${timeAgo(post.timestamp)}',
      style: small,
    );
    final replies =
        '${post.commentCount} ${post.commentCount == 1 ? 'reply' : 'replies'}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryLabel(categoryId: post.categoryId),
            const SizedBox(height: AppSpacing.sm),
            PostTitleHero(
              postId: post.id,
              title: post.title,
              maxLines: 2,
              style: theme.textTheme.titleMedium,
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
            // Polls can be answered right here in the feed.
            if (post.isPoll && post.isVisible) ...[
              const SizedBox(height: AppSpacing.md),
              LivePoll(post: post),
            ],
            const SizedBox(height: AppSpacing.md),
            // Team posts: the alias and badge get their own line, so the
            // badge has room next to the counts on a small phone.
            if (team && !gentle) ...[aliasLine, const SizedBox(height: 4)],
            Row(
              children: [
                Expanded(
                  child: team && !gentle ? const SizedBox.shrink() : aliasLine,
                ),
                if (!gentle) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text('${post.meTooCount} me too', style: small),
                  const SizedBox(width: AppSpacing.md),
                  Text(replies, style: small),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
