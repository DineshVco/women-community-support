import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/content_filter.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/report.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/category_label.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_tile.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/quick_exit_button.dart';

/// One discussion: the post, "Me too", replies (one level deep) and the
/// reply box. Everything updates live.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.showHiddenContent = false,
  });

  final String postId;

  /// Moderators open hidden posts from the queue so they can read them
  /// before deciding. Everyone else only sees a short notice.
  final bool showHiddenContent;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostRepository _repo;
  late final Stream<Post?> _postStream;
  late final Stream<List<Comment>> _commentsStream;
  late final Stream<bool> _meTooStream;

  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  bool _isMine = false;
  bool _sending = false;
  bool _meTooBusy = false;
  bool _deleting = false;

  /// The comment being answered (shown as "Replying to ...").
  Comment? _replyingTo;

  /// The top-level comment the reply attaches to. Replying to a reply
  /// attaches to its parent, so threads stay one level deep.
  String? _replyParentId;

  @override
  void initState() {
    super.initState();
    _repo = context.read<PostRepository>();
    _postStream = _repo.watchPost(widget.postId);
    _commentsStream = _repo.watchComments(widget.postId);
    _meTooStream = _repo.watchMeToo(widget.postId);

    _repo.isMyPost(widget.postId).then((mine) {
      if (mounted) setState(() => _isMine = mine);
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ───────────────────────── Replies ─────────────────────────

  void _startReply(Comment comment, String parentId) {
    setState(() {
      _replyingTo = comment;
      _replyParentId = parentId;
    });
    _replyFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyParentId = null;
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    if (ContentFilter.isDisrespectful(text)) {
      _showMessage('Please keep it respectful. Remove any abusive words '
          'and try again.');
      return;
    }

    setState(() => _sending = true);
    try {
      await _repo.addComment(
        postId: widget.postId,
        content: text,
        parentCommentId: _replyParentId,
      );
      if (!mounted) return;
      _replyController.clear();
      _replyFocus.unfocus();
      setState(() {
        _replyingTo = null;
        _replyParentId = null;
      });
    } catch (_) {
      if (mounted) _showMessage('Could not send your reply. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ───────────────────────── "Me too" ─────────────────────────

  Future<void> _toggleMeToo(bool currentlyOn) async {
    if (_meTooBusy) return;
    setState(() => _meTooBusy = true);
    try {
      await _repo.setMeToo(widget.postId, on: !currentlyOn);
    } catch (_) {
      if (mounted) _showMessage('Could not update. Please try again.');
    } finally {
      if (mounted) setState(() => _meTooBusy = false);
    }
  }

  // ───────────────────────── Report ─────────────────────────

  Future<void> _report(Post post) async {
    if (await _repo.hasReported(post.id)) {
      if (mounted) {
        _showMessage('You already reported this post. You can see what '
            'happened to it under Me.');
      }
      return;
    }
    if (!mounted) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReportSheet(),
    );
    if (reason == null || !mounted) return;

    try {
      await _repo.reportPost(post: post, reason: reason);
      if (mounted) {
        _showMessage('Thank you. A moderator will review it. You can follow '
            'the outcome under Me.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not send the report. Please try again.');
    }
  }

  // ───────────────────────── Delete ─────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
          'The post will disappear for everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await _repo.deletePost(widget.postId);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your post was deleted.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        _showMessage('Could not delete the post. Please try again.');
      }
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Post?>(
      stream: _postStream,
      builder: (context, snapshot) {
        final post = snapshot.data;

        Widget body;
        if (snapshot.hasError) {
          body = EmptyState(
            title: 'Could not load this discussion',
            message: 'Check your internet connection and try again.',
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).pop(),
          );
        } else if (_deleting ||
            snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (post == null) {
          body = const EmptyState(
            title: 'This discussion is gone',
            message: 'The person who started it deleted it.',
          );
        } else if (!post.isVisible && !widget.showHiddenContent) {
          body = EmptyState(
            title: post.status == 'removed'
                ? 'Removed by a moderator'
                : 'Hidden for review',
            message: post.status == 'removed'
                ? 'This post broke the community rules, so it was removed.'
                : 'Several members reported this post. It is hidden until a '
                    'moderator reviews it.',
          );
        } else {
          body = _buildDiscussion(post);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Discussion'),
            actions: [
              const QuickExitButton(),
              if (post != null && !_deleting) _buildMenu(post),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: SafeArea(top: false, child: body),
        );
      },
    );
  }

  Widget _buildMenu(Post post) {
    final canReport = !_isMine && post.isVisible;
    if (!canReport && !_isMine) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'More options',
      onSelected: (value) {
        if (value == 'report') _report(post);
        if (value == 'delete') _confirmDelete();
      },
      itemBuilder: (_) => [
        if (canReport)
          const PopupMenuItem(
            value: 'report',
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('Report post'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (_isMine)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: context.palette.danger),
              title: Text(
                'Delete my post',
                style: TextStyle(color: context.palette.danger),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildDiscussion(Post post) {
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: StreamBuilder<List<Comment>>(
              stream: _commentsStream,
              builder: (context, commentsSnapshot) {
                return ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    ..._buildPost(post),
                    const Divider(),
                    ..._buildComments(post, commentsSnapshot),
                  ],
                );
              },
            ),
          ),
        ),
        if (post.isVisible)
          CommentComposer(
            controller: _replyController,
            focusNode: _replyFocus,
            onSend: _sendReply,
            sending: _sending,
            replyingToAlias: _replyingTo?.alias,
            onCancelReply: _cancelReply,
          ),
      ],
    );
  }

  List<Widget> _buildPost(Post post) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return [
      if (!post.isVisible)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Text(
              post.status == 'removed'
                  ? 'Removed. Members cannot see this post.'
                  : 'Hidden after reports. Members cannot see this post '
                      'until it is reviewed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.danger,
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
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
            Text(post.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isMine ? 'Started by you as ${post.alias}' : 'Started by ${post.alias}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(post.content, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            if (post.isVisible)
              _buildMeTooButton(post)
            else
              Text(
                '${post.meTooCount} me too',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildMeTooButton(Post post) {
    final palette = context.palette;

    return StreamBuilder<bool>(
      stream: _meTooStream,
      builder: (context, snapshot) {
        final on = snapshot.data ?? false;
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Semantics(
          toggled: on,
          child: OutlinedButton.icon(
            onPressed:
                (loading || _meTooBusy) ? null : () => _toggleMeToo(on),
            style: on
                ? OutlinedButton.styleFrom(
                    backgroundColor: palette.primarySoft,
                    foregroundColor: palette.primary,
                    side: BorderSide(color: palette.primary),
                  )
                : null,
            icon: Icon(on ? Icons.favorite : Icons.favorite_border, size: 20),
            label: Text('Me too  ·  ${post.meTooCount}'),
          ),
        );
      },
    );
  }

  List<Widget> _buildComments(
    Post post,
    AsyncSnapshot<List<Comment>> snapshot,
  ) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final heading = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      child: Text(
        snapshot.hasData ? 'Replies (${snapshot.data!.length})' : 'Replies',
        style: theme.textTheme.headlineSmall,
      ),
    );

    Widget note(String text) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.md,
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        );

    if (snapshot.hasError) {
      return [heading, note('Could not load replies.')];
    }
    if (!snapshot.hasData) {
      return [
        heading,
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final comments = snapshot.data!;
    if (comments.isEmpty) {
      return [
        heading,
        note(post.isVisible
            ? 'No replies yet. Be the first to answer kindly.'
            : 'No replies.'),
      ];
    }

    // Build one-level threads. A reply whose parent was deleted is shown
    // as a normal top-level comment.
    final byId = {for (final c in comments) c.id: c};
    final topLevel = <Comment>[];
    final repliesByParent = <String, List<Comment>>{};

    for (final comment in comments) {
      final root = _rootId(comment, byId);
      if (root == comment.id) {
        topLevel.add(comment);
      } else {
        repliesByParent.putIfAbsent(root, () => []).add(comment);
      }
    }

    final canReply = post.isVisible;

    return [
      heading,
      for (final comment in topLevel) ...[
        CommentTile(
          comment: comment,
          isAuthor: comment.alias == post.alias,
          onReply: canReply ? () => _startReply(comment, comment.id) : null,
        ),
        for (final reply in repliesByParent[comment.id] ?? const <Comment>[])
          CommentTile(
            comment: reply,
            isReply: true,
            isAuthor: reply.alias == post.alias,
            onReply: canReply ? () => _startReply(reply, comment.id) : null,
          ),
      ],
    ];
  }

  /// Walks up the parent chain to the top-level comment.
  String _rootId(Comment comment, Map<String, Comment> byId) {
    var current = comment;
    // The limit stops a loop if the data is ever malformed.
    for (var i = 0; i < 10; i++) {
      final parentId = current.parentCommentId;
      final parent = parentId == null ? null : byId[parentId];
      if (parent == null) return current.id;
      current = parent;
    }
    return current.id;
  }
}

/// Bottom sheet: pick a reason, then send.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report this post', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your report is private. The author is not told who reported it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final reason in ReportReasons.all)
              Semantics(
                selected: _reason == reason,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => setState(() => _reason = reason),
                  leading: Icon(
                    _reason == reason
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _reason == reason ? palette.primary : null,
                  ),
                  title: Text(reason),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop(_reason),
                child: const Text('Send report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
