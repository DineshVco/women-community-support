import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/post.dart';
import 'category_label.dart';

/// One row in the feed. Flat: no shadow, no card, separated by hairlines.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryLabel(categoryId: post.categoryId),
                const SizedBox(width: AppSpacing.sm),
                Text(timeAgo(post.timestamp), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${post.alias}  ·  ${post.meTooCount} me too  ·  '
              '${post.commentCount} ${post.commentCount == 1 ? 'reply' : 'replies'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
