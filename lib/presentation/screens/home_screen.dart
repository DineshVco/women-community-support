import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/first_post_celebration.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/category.dart';
import '../../data/models/community.dart';
import '../../data/models/post.dart';
import '../../data/microcopy.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/community_cards.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/feed_greeting.dart';
import '../widgets/ios.dart';
import '../widgets/post_actions.dart';
import '../widgets/living_cat.dart';
import '../widgets/post_route.dart';
import '../widgets/looma_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/post_card.dart';
import '../widgets/press_scale.dart';
import '../widgets/heart_burst.dart';
import '../widgets/posted_confirmation.dart';
import '../widgets/question_of_the_day.dart';
import '../widgets/quick_exit_button.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import '../../core/theme/app_icons.dart';

/// The discussion feed: search, category filter, newest first.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Shown only when there are no discussions (from microcopy.json).
  static String get emptyMessage => Microcopy.emptyFeed;

  /// "Write a post" comes back this long after the feed stops moving.
  static const Duration pillReturnDelay = Duration(milliseconds: 300);

  /// Scrolling down further than this (px) hides it.
  static const double pillHideAfter = 8;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<List<Post>> _feed;
  String? _categoryId; // null = all categories
  String _query = '';

  /// Posts that have already played their entrance animation.
  final Set<String> _shownPostIds = {};

  /// "Write a post" is always there when the feed is at rest. It hides
  /// only while she scrolls down, and comes back when she scrolls up, is
  /// at the top, or stops scrolling for [HomeScreen.pillReturnDelay].
  bool _pillShown = true;

  /// Brings the pill back once scrolling has stopped.
  Timer? _pillReturn;

  /// How far she has scrolled down since the pill last showed (a little
  /// jitter does not hide it).
  double _downTravel = 0;

  final ScrollController _scrollController = ScrollController();

  /// The name the greeting uses (chosen in sign-up or Me, or her Google
  /// first name); kept live, so a change in Me shows at once.
  String? _greetingName;

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
      )
      ..add(
        repo.watchGreetingName().listen(
          (name) => setState(() => _greetingName = name),
          onError: (Object _) {},
        ),
      );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _pillReturn?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSmallWins(SmallWinsThread thread) {
    Navigator.of(context).push(
      PostRoute<void>(
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

    AppHaptics.light();
    showPostedConfirmation(context, alias: alias);
    LivingCat.cue(CatCue.wave);
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

  void _setPill(bool shown) {
    if (shown) _downTravel = 0;
    if (shown != _pillShown && mounted) setState(() => _pillShown = shown);
  }

  /// Decides from the feed's own movement (not the finger's direction), so
  /// iPhone momentum and the overscroll bounce cannot confuse it:
  ///  * at or above the top (and pull to refresh): shown;
  ///  * bouncing past the end: no change;
  ///  * moving down by more than a few pixels: hidden;
  ///  * moving up: shown;
  ///  * every movement restarts a short timer; when the feed has been
  ///    still for [HomeScreen.pillReturnDelay], it is shown again.
  /// A short list that cannot scroll never hides it.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final m = n.metrics;
    if (n is ScrollUpdateNotification && n.scrollDelta != null) {
      final delta = n.scrollDelta!;
      if (m.pixels <= m.minScrollExtent) {
        _setPill(true);
      } else if (m.pixels >= m.maxScrollExtent) {
        // The bounce at the end: its direction means nothing.
      } else if (delta > 0) {
        _downTravel += delta;
        if (_downTravel > HomeScreen.pillHideAfter) _setPill(false);
      } else if (delta < -1) {
        _setPill(true);
      }
    }
    if (n is ScrollUpdateNotification ||
        n is ScrollEndNotification ||
        n is OverscrollNotification) {
      _pillReturn?.cancel();
      _pillReturn = Timer(HomeScreen.pillReturnDelay, () => _setPill(true));
    }
    return false;
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      PostRoute<void>(
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

    final palette = context.palette;
    final visible = _pillShown;
    final pillMotion = AppMotion.of(context, AppMotion.medium);
    final fab = SizedBox(
      child: IgnorePointer(
        key: const ValueKey('write-pill-gate'),
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          // Fades and shrinks a little in place (never moves), so it never
          // passes over anything while it comes back.
          child: AnimatedScale(
            scale: visible ? 1 : 0.85,
            duration: pillMotion,
            curve: visible ? AppMotion.enter : AppMotion.exit,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: pillMotion,
              child: WritePill(
                extended: true,
                onPressed: () {
                  AppHaptics.light();
                  _openCompose();
                },
              ),
            ),
          ),
        ),
      ),
    );

    return StreamBuilder<List<Post>>(
      stream: _feed,
      builder: (context, snapshot) {
        Widget wide(Widget child) => ContentWidth(child: child);
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: LargeTitleScaffold(
            title: 'Discuss',
            controller: _scrollController,
            onRefresh: _refresh,
            trailing: const QuickExitButton(),
            floatingActionButton: fab,
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
                  wide(FeedGreeting(name: _greetingName)),
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
                ]),
              ),
              // Search and filters stay pinned under the header while the
              // hero and the question card scroll away.
              PinnedHeaderSliver(
                child: ColoredBox(
                  key: const ValueKey('discuss-filters'),
                  color: palette.background,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      wide(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            6,
                            AppSpacing.screenHorizontal,
                            6,
                          ),
                          child: CupertinoSearchTextField(
                            placeholder: 'Search discussions',
                            onChanged:
                                (value) => setState(() => _query = value),
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
                                    onTap:
                                        () => setState(() => _categoryId = id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  for (final child in _buildBody(context, snapshot, theme))
                    wide(child),
                  // Room for the "Write a post" pill, so it never covers the
                  // last card.
                  const SizedBox(height: WritePill.room),
                ]),
              ),
            ],
          ),
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
      // Cards in the shape of real posts while the feed loads.
      return const [SkeletonPostList(label: 'Loading discussions')];
    }

    final allPosts = snapshot.data!;
    final posts = _applyFilters(allPosts);

    if (allPosts.isEmpty) {
      return [
        CatEmptyState(
          line: HomeScreen.emptyMessage,
          actionLabel: 'Write a post',
          onAction: _openCompose,
        ),
      ];
    }

    if (posts.isEmpty) {
      // Search or a category found nothing.
      return [CatEmptyState(line: Microcopy.emptySearch)];
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
          child: PostContextMenu(
            post: post,
            child: PostCard(post: post, onTap: () => _openPost(post)),
          ),
        ),
      );
    }
    return rows;
  }
}

/// "Write a post": a small black pill (44 px high) that folds to just the
/// pencil while scrolling down and opens again on the way up.
class WritePill extends StatelessWidget {
  const WritePill({super.key, required this.extended, required this.onPressed});

  final bool extended;
  final VoidCallback onPressed;

  static const double height = 44;

  /// Space kept under the last card: the pill, its 16 px margin and a gap.
  static const double room = height + 16 + 16;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Write a post',
      excludeSemantics: true,
      child: PressScale(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            shadows: LoomaCard.shadowFor(Theme.of(context).brightness),
          ),
          child: Material(
            color: palette.writePill,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.write,
                        size: 20,
                        color: palette.onWritePill,
                      ),
                      // The label folds away while scrolling down.
                      GentleSize(
                        curve: AppMotion.spring,
                        alignment: Alignment.centerLeft,
                        child:
                            extended
                                ? Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Write a post',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: palette.onWritePill,
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
