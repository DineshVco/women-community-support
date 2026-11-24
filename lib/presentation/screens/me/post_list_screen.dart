import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/post.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/post_card.dart';
import '../post_detail_screen.dart';
import '../../widgets/ios.dart';
import '../../widgets/post_route.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/quick_exit_button.dart';

/// A simple list of posts for "My posts" and "Saved posts" (Me tab).
/// Only she can see these lists.
class PostListScreen extends StatefulWidget {
  const PostListScreen({
    super.key,
    required this.title,
    required this.load,
    required this.emptyMessage,
    this.note,
    this.emptyPicture,
  });

  final String title;
  final Future<List<Post>> Function() load;
  final String emptyMessage;

  /// A picture for the empty list instead of the sleeping cat, with its
  /// width / height.
  final (String, double)? emptyPicture;

  /// One line above the list, e.g. "Only you can see this list."
  final String? note;

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  late Future<List<Post>> _posts = widget.load();

  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _posts = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  Future<void> _open(Post post) async {
    await Navigator.of(context).push(
      PostRoute<void>(
        builder: (_) => PostDetailScreen(postId: post.id, initialPost: post),
      ),
    );
    // She may have unsaved or deleted it.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: widget.title,
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: FutureBuilder<List<Post>>(
            future: _posts,
            builder: (context, snapshot) {
              final List<Widget> children;
              if (snapshot.hasError) {
                children = [
                  EmptyState(
                    title: 'Could not load this list',
                    message: 'Check your internet connection and try again.',
                    actionLabel: 'Try again',
                    onAction: _reload,
                  ),
                ];
              } else if (!snapshot.hasData) {
                children = const [SkeletonPostList()];
              } else if (snapshot.data!.isEmpty) {
                final picture = widget.emptyPicture;
                children = [
                  picture == null
                      ? CatEmptyState(line: widget.emptyMessage)
                      : CatEmptyState(
                        line: widget.emptyMessage,
                        picture: picture.$1,
                        pictureAspect: picture.$2,
                      ),
                ];
              } else {
                children = [
                  if (widget.note != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.md,
                        AppSpacing.screenHorizontal,
                        0,
                      ),
                      child: Text(
                        widget.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final post in snapshot.data!)
                    PostCard(post: post, onTap: () => _open(post)),
                ];
              }
              // iOS pull-to-refresh spinner.
              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _reload),
                  SliverList(delegate: SliverChildListDelegate(children)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
