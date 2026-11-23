import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/post.dart';
import '../providers/app_settings.dart';
import 'alias_avatar.dart';
import 'category_label.dart';
import 'looma_card.dart';
import 'poll_view.dart';
import 'post_title_hero.dart';
import 'tap_zone.dart';
import 'team_badge.dart';

/// One post in the feed, as a card (12 px apart):
///  [Health]
///  Title (Newsreader 22)
///  Two lines of preview
///  (avatar) Quiet Fox · 2h               heart 4   bubble 3
/// The team is shown once, as its black badge. Gentle mode hides the
/// numbers. Polls can be answered right on the card.
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
    final replies =
        '${post.commentCount} ${post.commentCount == 1 ? 'reply' : 'replies'}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: LoomaCard.gap / 2,
      ),
      child: LoomaCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryLabel(categoryId: post.categoryId),
            const SizedBox(height: 10),
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
              // Kept clear of floating buttons (see TapZone).
              TapZone(
                key: ValueKey('poll-answers-${post.id}'),
                child: LivePoll(post: post),
              ),
            ],
            const SizedBox(height: 10),
            TapZone(
              key: ValueKey('post-counts-${post.id}'),
              child: Row(
                children: [
                  AliasAvatar(alias: post.alias),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AliasLine(
                      alias: post.alias,
                      text: post.alias,
                      trailing:
                          LoomaTeam.isTeam(post.alias)
                              ? '  ${timeAgo(post.timestamp)}'
                              : ' · ${timeAgo(post.timestamp)}',
                      style: small,
                    ),
                  ),
                  if (!gentle) ...[
                    _Count(
                      icon: AppIcons.meToo,
                      count: post.meTooCount,
                      label: '${post.meTooCount} me too',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _Count(
                      icon: AppIcons.reply,
                      count: post.commentCount,
                      label: replies,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon with a number, read out as e.g. "4 me too".
class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.count, required this.label});

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
