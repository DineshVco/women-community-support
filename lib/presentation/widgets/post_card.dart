import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';


class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: theme.dividerColor,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author + category
            Row(
              children: [
                _AuthorAvatar(
                  isAnonymous: post.isAnonymous,
                  displayName: post.displayName,
                ),

                const SizedBox(width: AppSpacing.md),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.isAnonymous
                            ? 'Anonymous'
                            : post.displayName,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(post.timestamp),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                _CategoryChip(
  label: _categoryName(post.categoryId),
  categoryId: post.categoryId,
),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              post.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Content
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Engagement
            Row(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 19,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${_mockLikeCount(post.id)}',
                  style: theme.textTheme.bodySmall,
                ),

                const SizedBox(width: AppSpacing.xl),

                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${_mockCommentCount(post.id)}',
                  style: theme.textTheme.bodySmall,
                ),

                const Spacer(),

                Icon(
                  Icons.more_horiz_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryName(String categoryId) {
    switch (categoryId) {
      case 'health_wellness':
        return 'Health & Wellness';
      case 'education':
        return 'Education';
      case 'career_development':
        return 'Career Development';
      case 'personal_safety':
        return 'Personal Safety';
      default:
        return 'Community';
    }
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  int _mockLikeCount(String postId) {
    switch (postId) {
      case 'mock_health':
        return 12;
      case 'mock_career':
        return 18;
      case 'mock_safety':
        return 24;
      default:
        return 0;
    }
  }

  int _mockCommentCount(String postId) {
    switch (postId) {
      case 'mock_health':
        return 5;
      case 'mock_career':
        return 7;
      case 'mock_safety':
        return 9;
      default:
        return 0;
    }
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.isAnonymous,
    required this.displayName,
  });

  final bool isAnonymous;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isAnonymous
            ? Icons.person_outline_rounded
            : Icons.person_rounded,
        size: 22,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.categoryId,
  });

  final String label;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (backgroundColor, foregroundColor) = _colors(theme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foregroundColor,
        ),
      ),
    );
  }

  (Color, Color) _colors(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    switch (categoryId) {
      case 'health_wellness':
        return (
          isDark ? AppColors.darkHealthSoft : AppColors.healthSoft,
          isDark ? AppColors.darkHealth : AppColors.health,
        );

      case 'education':
        return (
          isDark ? AppColors.darkEducationSoft : AppColors.educationSoft,
          isDark ? AppColors.darkEducation : AppColors.education,
        );

      case 'career_development':
        return (
          isDark ? AppColors.darkCareerSoft : AppColors.careerSoft,
          isDark ? AppColors.darkCareer : AppColors.career,
        );

      case 'personal_safety':
        return (
          isDark ? AppColors.darkSafetySoft : AppColors.safetySoft,
          isDark ? AppColors.darkSafety : AppColors.safety,
        );

      default:
        return (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.primary,
        );
    }
  }
}