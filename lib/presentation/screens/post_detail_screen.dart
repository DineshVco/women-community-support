import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/content_filter.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/report.dart';
import '../../data/repositories/post_repository.dart';
import '../providers/app_settings.dart';
import '../widgets/adaptive.dart';
import '../widgets/category_label.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_tile.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/post_title_hero.dart';
import '../widgets/press_scale.dart';
import '../widgets/quick_exit_button.dart';

/// One discussion: the post, "Me too", replies (one level deep) and the
/// reply box. Everything updates live.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.showHiddenContent = false,
  });

  final String postId;

  /// The post as the feed already has it. Shown straight away (so the title
  /// can fly in) until the live copy arrives.
  final Post? initialPost;

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
  late final Stream<bool> _savedStream;

  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  bool _isMine = false;

  /// Her alias in this discussion, for "Reply as …" (null while loading).
  String? _myAlias;
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
    _savedStream = _repo.watchSaved(widget.postId);

    _repo
        .myAliasFor(widget.postId)
        .then((alias) {
          if (mounted) setState(() => _myAlias = alias);
        })
        .catchError((Object _) {});

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
      _showMessage(
        'Please keep it respectful. Remove any abusive words '
        'and try again.',
      );
      return;
    }

    AppHaptics.light();
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
    AppHaptics.selection(); // Looma spec: selectionClick for "Me too".
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
        _showMessage(
          'You already reported this post. You can see what '
          'happened to it under Me.',
        );
      }
      return;
    }
    if (!mounted) return;

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
    if (reason == null || !mounted) return;

    try {
      await _repo.reportPost(post: post, reason: reason);
      AppHaptics.medium();
      if (mounted) {
        _showMessage(
          'Thank you. A moderator will review it. You can follow '
          'the outcome under Me.',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Could not send the report. Please try again.');
    }
  }

  // ───────────────────────── Delete ─────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this post?',
      message: 'The post will disappear for everyone. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

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
      initialData: widget.initialPost,
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
            (post == null &&
                snapshot.connectionState == ConnectionState.waiting)) {
          body = const Center(child: CircularProgressIndicator());
        } else if (post == null) {
          body = const EmptyState(
            title: 'This discussion is gone',
            message: 'The person who started it deleted it.',
          );
        } else if (!post.isVisible && !widget.showHiddenContent) {
          body = EmptyState(
            title:
                post.status == 'removed'
                    ? 'Removed by a moderator'
                    : 'Hidden for review',
            message:
                post.status == 'removed'
                    ? 'This post broke the community rules, so it was removed.'
                    : 'Several members reported this post. It is hidden until a '
                        'moderator reviews it.',
          );
        } else {
          body = _buildDiscussion(post);
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              const QuickExitButton(),
              if (post != null && post.isVisible && !_deleting)
                _buildSaveButton(),
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
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        if (value == 'report') _report(post);
        if (value == 'delete') _confirmDelete();
      },
      itemBuilder:
          (_) => [
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
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.palette.danger,
                  ),
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
            hintText: _myAlias == null ? 'Write a reply' : 'Reply as $_myAlias',
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
            CategoryLabel(categoryId: post.categoryId),
            const SizedBox(height: AppSpacing.sm),
            PostTitleHero(
              postId: post.id,
              title: post.title,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_isMine ? 'You, as ${post.alias}' : post.alias}'
              ' · ${timeAgo(post.timestamp)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(post.content, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            if (post.isVisible)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _buildMeTooButton(post),
                  if (!_isMine)
                    PressScale(
                      child: OutlinedButton.icon(
                        onPressed: () => _report(post),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.danger,
                          side: BorderSide(color: palette.danger, width: 1.5),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('Report'),
                      ),
                    ),
                ],
              )
            else if (!AppSettings.gentleOf(context))
              Text(
                '${post.meTooCount} me too',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    ];
  }

  /// Bookmark: adds the post to "Saved posts" in the Me tab (private).
  Widget _buildSaveButton() {
    return StreamBuilder<bool>(
      stream: _savedStream,
      builder: (context, snapshot) {
        final saved = snapshot.data ?? false;
        return IconButton(
          tooltip: saved ? 'Remove from saved' : 'Save',
          isSelected: saved,
          icon: const Icon(Icons.bookmark_border),
          selectedIcon: const Icon(Icons.bookmark),
          onPressed:
              snapshot.hasData
                  ? () async {
                    AppHaptics.light();
                    try {
                      await _repo.setSaved(widget.postId, saved: !saved);
                    } catch (_) {
                      _showMessage('Could not update your saved posts.');
                    }
                  }
                  : null,
        );
      },
    );
  }

  Widget _buildMeTooButton(Post post) {
    final palette = context.palette;

    return StreamBuilder<bool>(
      stream: _meTooStream,
      builder: (context, snapshot) {
        final on = snapshot.data ?? false;
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Semantics(
          toggled: on,
          child: PressScale(
            child: OutlinedButton.icon(
              onPressed:
                  (loading || _meTooBusy) ? null : () => _toggleMeToo(on),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                // Pressed: soft blush with dark text (readable in both modes).
                backgroundColor: on ? palette.blush : null,
                foregroundColor: on ? palette.onBlush : palette.text,
                side: BorderSide(
                  color: on ? palette.blush : palette.primary,
                  width: 1.5,
                ),
              ),
              icon: _PopOnSelect(
                selected: on,
                child: Icon(
                  on ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                ),
              ),
              label: Text(
                AppSettings.gentleOf(context)
                    ? 'Me too'
                    : 'Me too · ${post.meTooCount}',
              ),
            ),
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
        snapshot.hasData && !AppSettings.gentleOf(context)
            ? 'Replies (${snapshot.data!.length})'
            : 'Replies',
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
        note(
          post.isVisible
              ? 'No replies yet. Be the first to answer kindly.'
              : 'No replies.',
        ),
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
      for (final (index, comment) in topLevel.indexed) ...[
        if (index > 0)
          const Divider(
            indent: AppSpacing.screenHorizontal,
            endIndent: AppSpacing.screenHorizontal,
          ),
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

/// Gives its child a quick "pop" (grow a little, settle back) whenever
/// [selected] turns on.
class _PopOnSelect extends StatefulWidget {
  const _PopOnSelect({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  State<_PopOnSelect> createState() => _PopOnSelectState();
}

class _PopOnSelectState extends State<_PopOnSelect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  // 1 → 1.3 quickly, then spring back to 1 (with a small bounce past it).
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.3,
        end: 1.0,
      ).chain(CurveTween(curve: AppMotion.springPop)),
      weight: 70,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(_PopOnSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected && !AppMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
