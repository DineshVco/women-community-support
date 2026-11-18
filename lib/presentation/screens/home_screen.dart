import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/brand_mark.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/post_card.dart';
import '../widgets/quick_exit_button.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

/// The discussion feed: search, category filter, newest first.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<List<Post>> _feed;
  String? _categoryId; // null = all categories
  String _query = '';

  @override
  void initState() {
    super.initState();
    _feed = context.read<PostRepository>().watchFeed();
  }

  void _retry() {
    setState(() => _feed = context.read<PostRepository>().watchFeed());
  }

  void _openCompose() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreatePostScreen()),
    );
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
  }

  List<Post> _applyFilters(List<Post> posts) {
    final query = _query.trim().toLowerCase();

    return posts.where((post) {
      if (_categoryId != null && post.categoryId != _categoryId) return false;
      if (query.isEmpty) return true;
      return post.title.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Write a post'),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: StreamBuilder<List<Post>>(
            stream: _feed,
            builder: (context, snapshot) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Wordmark(), QuickExitButton()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search discussions',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'All',
                          selected: _categoryId == null,
                          onTap: () => setState(() => _categoryId = null),
                        ),
                        for (final category in AppCategories.all)
                          _CategoryChip(
                            label: category.shortName,
                            selected: _categoryId == category.id,
                            onTap: () =>
                                setState(() => _categoryId = category.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  ..._buildBody(context, snapshot, theme),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    AsyncSnapshot<List<Post>> snapshot,
    ThemeData theme,
  ) {
    if (snapshot.hasError) {
      return [
        EmptyState(
          title: 'Could not load discussions',
          message: 'Check your internet connection and try again.',
          actionLabel: 'Try again',
          onAction: _retry,
        ),
      ];
    }

    if (!snapshot.hasData) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final allPosts = snapshot.data!;
    final posts = _applyFilters(allPosts);

    if (allPosts.isEmpty) {
      return [
        EmptyState(
          title: 'No discussions yet',
          message: 'Start the first one. You will post under a random alias.',
          actionLabel: 'Write a post',
          onAction: _openCompose,
        ),
      ];
    }

    if (posts.isEmpty) {
      final category =
          _categoryId == null ? null : AppCategories.fromId(_categoryId!);
      return [
        EmptyState(
          title: 'Nothing found',
          message: _query.trim().isNotEmpty
              ? 'No discussions match “${_query.trim()}”.'
              : 'There are no ${category?.shortName ?? ''} discussions yet.',
        ),
      ];
    }

    return [
      for (final post in posts) ...[
        PostCard(post: post, onTap: () => _openPost(post)),
        const Divider(),
      ],
    ];
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}
