import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';
import '../providers/comments_provider.dart';
import '../widgets/avatar.dart';
import '../widgets/comment_card.dart';
import '../widgets/comment_input.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.post,
  });

  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommentsProvider>().loadComments(widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuthor(theme),
            const SizedBox(height: AppSpacing.xxl),
            _buildCategory(theme),
            const SizedBox(height: AppSpacing.lg),
            _buildPostContent(theme),
            const SizedBox(height: AppSpacing.xxl),
            _buildPostActions(theme),
            const SizedBox(height: AppSpacing.section),
            _buildComments(theme),
            const SizedBox(height: AppSpacing.xxl),
            CommentInput(
              controller: _commentController,
              onSubmit: _submitComment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthor(ThemeData theme) {
    return Row(
      children: [
        Avatar(
          isAnonymous: widget.post.isAnonymous,
          displayName: widget.post.displayName,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.post.isAnonymous
                    ? 'Anonymous'
                    : widget.post.displayName,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(widget.post.timestamp),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategory(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        _categoryName(widget.post.categoryId),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPostContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.post.content,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPostActions(ThemeData theme) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.favorite_border_rounded,
          label: 'Like',
          onTap: () {},
        ),
        const SizedBox(width: AppSpacing.lg),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Comment',
          onTap: () {
            FocusScope.of(context).requestFocus();
          },
        ),
        const Spacer(),
        _ActionButton(
          icon: Icons.flag_outlined,
          label: 'Report',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildComments(ThemeData theme) {
    return Consumer<CommentsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading(widget.post.id)) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final error = provider.errorForPost(widget.post.id);

        if (error != null) {
          return Text(
            error,
            style: theme.textTheme.bodyMedium,
          );
        }

        final comments = provider.commentsForPost(widget.post.id);

        if (comments.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: theme.dividerColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No comments yet',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Be the first to share your thoughts.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ...comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                ),
                child: CommentCard(
                  comment: comment,
                  formatDate: _formatDate,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();

    if (content.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await context.read<CommentsProvider>().addComment(
            postId: widget.post.id,
            authorId: user.uid,
            isAnonymous: true,
            displayName: 'Anonymous',
            content: content,
          );

      _commentController.clear();

      if (!mounted) return;

      FocusScope.of(context).unfocus();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to add comment. Please try again.',
          ),
        ),
      );
    }
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
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}