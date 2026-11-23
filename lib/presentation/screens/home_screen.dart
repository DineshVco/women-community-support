import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/first_post_celebration.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/category.dart';
import '../../data/models/community.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/community_cards.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/feed_greeting.dart';
import '../widgets/floating_illustration.dart';
import '../widgets/ios.dart';
import '../widgets/post_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/heart_burst.dart';
import '../widgets/posted_confirmation.dart';
import '../widgets/question_of_the_day.dart';
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

  /// Posts that have already played their entrance animation.
  final Set<String> _shownPostIds = {};

  /// False while the person scrolls down: the button becomes just an icon.
  bool _fabExtended = true;

  final ScrollController _scrollController = ScrollController();

  /// This week's Small wins thread (pinned) and themed week, if running.
  SmallWinsThread? _smallWins;
  ThemedWeek? _themedWeek;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    final repo = context.read<PostRepository>();
    _feed = repo.watchFeed();
    // Extras: if they fail to load, Home simply shows without them.
    _subscriptions
      ..add(
        repo.watchSmallWins().listen(
          (t) => setState(() => _smallWins = t),
          onError: (Object _) {},
        ),
      )
      ..add(
        repo.watchThemedWeek().listen(
          (w) => setState(() => _themedWeek = w),
          onError: (Object _) {},
        ),
      );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _openSmallWins(SmallWinsThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(postId: thread.id, smallWins: true),
      ),
    );
  }

  void _retry() {
    setState(() => _feed = context.read<PostRepository>().watchFeed());
  }

  /// Pull to refresh: waits for a fresh copy of the feed, then reconnects
  /// the live list (this also recovers from a dropped connection).
  Future<void> _refresh() async {
    AppHaptics.medium();
    final repo = context.read<PostRepository>();
    try {
      await repo.watchFeed().first.timeout(const Duration(seconds: 10));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh. Check your connection.'),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _feed = repo.watchFeed());
  }

  Future<void> _openCompose({String? initialTitle}) async {
    final alias = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreatePostScreen(initialTitle: initialTitle),
      ),
    );
    if (alias == null || !mounted) return;

    showPostedConfirmation(context, alias: alias);
    _celebrateIfFirstPost();

    // Bring the new post (it slides in at the top) into view.
    if (_scrollController.hasClients) {
      if (AppMotion.reduced(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: AppMotion.slow,
          curve: AppMotion.enter,
        );
      }
    }
  }

  /// After her very first post: a small burst of blush hearts and a haptic.
  /// Once per account (flag kept on the phone, see FirstPostCelebration).
  Future<void> _celebrateIfFirstPost() async {
    final repo = context.read<PostRepository>();
    final uid = repo.myUid;
    if (uid == null) return;

    final first = await FirstPostCelebration.claim(
      uid,
      postCount: repo.myPostCount,
    );
    if (!first || !mounted) return;

    AppHaptics.medium();
    showHeartBurst(context);
  }

  /// Shrink the button while scrolling down the feed, grow it on the way up.
  bool _onUserScroll(UserScrollNotification notification) {
    // Ignore the sideways category chips.
    if (notification.metrics.axis != Axis.vertical) return false;

    final atTop = notification.metrics.pixels <= 0;
    final extended = switch (notification.direction) {
      ScrollDirection.reverse => atTop,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended || atTop,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(postId: post.id, initialPost: post),
      ),
    );
  }

  List<Post> _applyFilters(List<Post> posts) {
    final query = _query.trim().toLowerCase();

    return posts.where((post) {
      // The Small wins thread is pinned above, not repeated in the list.
      if (post.id == _smallWins?.id) return false;
      if (_categoryId != null && post.categoryId != _categoryId) return false;
      if (query.isEmpty) return true;
      return post.title.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fabDuration = AppMotion.of(context, AppMotion.medium);

    final palette = context.palette;
    final fab = FloatingActionButton.extended(
      onPressed: () {
        AppHaptics.light();
        _openCompose();
      },
      tooltip: 'Write a post',
      extendedPadding: EdgeInsets.symmetric(horizontal: _fabExtended ? 20 : 16),
      extendedIconLabelSpacing: _fabExtended ? 8 : 0,
      icon: const Icon(Icons.add),
      // The label folds away while scrolling down and returns on the way up.
      label: AnimatedSize(
        duration: fabDuration,
        curve: AppMotion.spring,
        alignment: Alignment.centerLeft,
        child:
            _fabExtended ? const Text('Write a post') : const SizedBox.shrink(),
      ),
    );

    return StreamBuilder<List<Post>>(
      stream: _feed,
      builder: (context, snapshot) {
        Widget wide(Widget child) => ContentWidth(child: child);
        return LargeTitleScaffold(
          title: 'Discuss',
          controller: _scrollController,
          onUserScroll: _onUserScroll,
          onRefresh: _refresh,
          trailing: const QuickExitButton(),
          floatingActionButton: fab,
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                wide(
                  FeedGreeting(
                    posts: snapshot.data,
                    onWrite: () => _openCompose(),
                  ),
                ),
                if (_themedWeek != null)
                  wide(ThemedWeekBanner(week: _themedWeek!)),
                if (_smallWins != null)
                  wide(
                    SmallWinsCard(
                      thread: _smallWins!,
                      onOpen: () => _openSmallWins(_smallWins!),
                    ),
                  ),
                wide(
                  QuestionOfTheDay(
                    onAnswer:
                        (question) => _openCompose(initialTitle: question),
                  ),
                ),
                wide(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                    ),
                    child: CupertinoSearchTextField(
                      placeholder: 'Search discussions',
                      onChanged: (value) => setState(() => _query = value),
                      style: TextStyle(color: palette.text),
                      backgroundColor: palette.softFill,
                    ),
                  ),
                ),
                wide(
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: Row(
                      children: [
                        for (final (id, label) in [
                          (null, 'All'),
                          for (final c in AppCategories.all)
                            (c.id, c.shortName),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                            ),
                            child: Pill(
                              label: label,
                              selected: _categoryId == id,
                              onTap: () => setState(() => _categoryId = id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                for (final child in _buildBody(context, snapshot, theme))
                  wide(child),
                // Room for the "Write a post" button.
                const SizedBox(height: 72),
              ]),
            ),
          ],
        );
      },
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
          illustration: LoomaCats.heart,
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
          illustration: LoomaCats.heart,
          title: 'Nothing found',
          message:
              _query.trim().isNotEmpty
                  ? 'No discussions match “${_query.trim()}”.'
                  : 'There are no ${category?.shortName ?? ''} discussions yet.',
        ),
      ];
    }

    // Rows fade and rise 8 px, 40 ms apart, on the first load only. Later
    // updates (new posts, searching, scrolling back) appear without motion.
    final firstLoad = _shownPostIds.isEmpty;
    var newRows = 0;
    final rows = <Widget>[];
    for (final post in posts) {
      final isNew = _shownPostIds.add(post.id) && firstLoad;
      // Stagger only the new rows, capped so a long list never lags.
      final delay =
          isNew ? AppMotion.stagger * (newRows++).clamp(0, 6) : Duration.zero;
      rows.add(
        FadeSlideIn(
          key: ValueKey(post.id),
          animate: isNew,
          delay: delay,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PostContextMenu(
                post: post,
                child: PostCard(post: post, onTap: () => _openPost(post)),
              ),
              const Divider(),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}
