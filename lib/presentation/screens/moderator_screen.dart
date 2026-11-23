import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/time_format.dart';
import '../../data/content_library.dart';
import '../../data/help_lines.dart';
import '../../data/models/report.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/adaptive.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/press_scale.dart';
import '../widgets/ios.dart';
import '../widgets/post_route.dart';
import '../widgets/skeleton.dart';
import 'post_detail_screen.dart';

/// Open reports, grouped by post. A moderator reads the post, then keeps it
/// or removes it. Either choice closes every open report on that post.
///
/// Only people with a `moderators/{uid}` document can load this list
/// (firestore.rules), so opening it as anyone else just shows an error.
class ModeratorScreen extends StatefulWidget {
  /// One entry per reported post or reply, oldest report first, so nothing
  /// waits too long.
  static List<ReportedItem> group(List<Report> reports) {
    final items = <String, ReportedItem>{};
    for (final report in reports) {
      final key =
          report.commentId == null
              ? report.postId
              : '${report.postId}/${report.commentId}';
      items
          .putIfAbsent(
            key,
            () => ReportedItem(
              postId: report.postId,
              commentId: report.commentId,
              title: report.postTitle,
              firstReportedAt: report.createdAt,
            ),
          )
          .reasons
          .add(report.reason);
    }
    return items.values.toList()
      ..sort((a, b) => a.firstReportedAt.compareTo(b.firstReportedAt));
  }

  const ModeratorScreen({super.key});

  /// This week's prompt from content/small_wins.json (changes weekly).
  static String smallWinsPromptFor(List<String> prompts, DateTime date) {
    if (prompts.isEmpty) return 'Small wins this week: what went well?';
    final week =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(2024, 1, 1)).inDays ~/
        7;
    return prompts[week % prompts.length];
  }

  @override
  State<ModeratorScreen> createState() => _ModeratorScreenState();
}

class _ModeratorScreenState extends State<ModeratorScreen> {
  late final PostRepository _repo;
  late final Stream<List<Report>> _openReports;

  /// Posts with a decision being saved right now.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _repo = context.read<PostRepository>();
    _openReports = _repo.watchOpenReports();
  }

  void _openPost(String postId) {
    Navigator.of(context).push(
      PostRoute<void>(
        builder:
            (_) => PostDetailScreen(postId: postId, showHiddenContent: true),
      ),
    );
  }

  Future<void> _decide(ReportedItem item, {required bool remove}) async {
    final what = item.isReply ? 'reply' : 'post';
    if (remove) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove this $what?',
        message:
            item.isReply
                ? 'The reply will be removed for everyone. The people who '
                    'reported it will see that it was removed.'
                : '“${item.title}” will be removed for everyone. The people '
                    'who reported it will see that it was removed.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(item.key));
    try {
      if (item.isReply) {
        await _repo.resolveCommentReports(
          postId: item.postId,
          commentId: item.commentId!,
          removeReply: remove,
        );
      } else {
        await _repo.resolvePostReports(postId: item.postId, removePost: remove);
      }
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            remove
                ? '${item.isReply ? 'Reply' : 'Post'} removed.'
                : '${item.isReply ? 'Reply' : 'Post'} kept and visible.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save the decision. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(item.key));
    }
  }

  Future<void> _startSmallWins() async {
    final ready = ContentScope.maybeOf(context);
    final library = ready ?? await ContentLibrary.load();
    if (!mounted) return;
    final title = ModeratorScreen.smallWinsPromptFor(
      library.smallWinsPrompts,
      DateTime.now(),
    );
    final confirmed = await showConfirmDialog(
      context,
      title: 'Start this week\'s Small wins?',
      message:
          '"$title" will be pinned at the top of Discuss for 7 days, posted '
          'as Looma Team.',
      confirmLabel: 'Start',
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.startSmallWins(title);
      AppHaptics.medium();
      messenger.showSnackBar(
        const SnackBar(content: Text('Small wins is pinned for 7 days.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start it. If you posted a moment ago, wait a minute.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'Report queue',
        trailing: TextButton(
          onPressed: _startSmallWins,
          child: const Text('Small wins'),
        ),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: StreamBuilder<List<Report>>(
            stream: _openReports,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  title: 'Could not load reports',
                  message:
                      'Check your connection. Only moderators can see '
                      'this list.',
                );
              }
              if (!snapshot.hasData) {
                return const SingleChildScrollView(
                  child: SkeletonPostList(label: 'Loading reports'),
                );
              }

              final items = ModeratorScreen.group(snapshot.data!);
              if (items.isEmpty) {
                return const EmptyState(
                  title: 'All clear',
                  message: 'There are no open reports right now.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ReportedRow(
                    item: item,
                    repo: _repo,
                    busy: _busy.contains(item.key),
                    onRead: () => _openPost(item.postId),
                    onKeep: () => _decide(item, remove: false),
                    onRemove: () => _decide(item, remove: true),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One thing in the queue: a post, or a reply in a post.
class ReportedItem {
  ReportedItem({
    required this.postId,
    required this.title,
    required this.firstReportedAt,
    this.commentId,
  });

  final String postId;
  final String? commentId;
  final String title;
  final DateTime firstReportedAt;
  final List<String> reasons = [];

  bool get isReply => commentId != null;

  /// Posts and each of their replies are separate items.
  String get key => commentId == null ? postId : '$postId/$commentId';
}

class _ReportedRow extends StatelessWidget {
  const _ReportedRow({
    required this.item,
    required this.repo,
    required this.busy,
    required this.onRead,
    required this.onKeep,
    required this.onRemove,
  });

  final ReportedItem item;
  final PostRepository repo;
  final bool busy;
  final VoidCallback onRead;
  final VoidCallback onKeep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    // "Harassment or hate ×2", "Spam or advertising"
    final counts = <String, int>{};
    for (final reason in item.reasons) {
      counts[reason] = (counts[reason] ?? 0) + 1;
    }
    final reasonText = counts.entries
        .map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key)
        .join('  ·  ');
    final count = item.reasons.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count ${count == 1 ? 'report' : 'reports'}  ·  first '
            '${timeAgo(item.firstReportedAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.warning,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.isReply
                ? 'Reply in “${item.title.isEmpty ? 'Untitled post' : item.title}”'
                : (item.title.isEmpty ? 'Untitled post' : item.title),
            style: theme.textTheme.titleMedium,
          ),
          // A reply: show what it says, so the decision is informed.
          if (item.isReply)
            FutureBuilder(
              future: repo.commentFor(item.postId, item.commentId!),
              builder:
                  (context, snapshot) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      snapshot.data?.content ??
                          (snapshot.hasError
                              ? 'Could not load the reply.'
                              : 'Loading the reply…'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(reasonText, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: busy ? null : onRead,
                child: Text(item.isReply ? 'Read discussion' : 'Read post'),
              ),
              PressScale(
                enabled: !busy,
                child: OutlinedButton(
                  onPressed: busy ? null : onKeep,
                  child: Text(item.isReply ? 'Keep reply' : 'Keep post'),
                ),
              ),
              PressScale(
                enabled: !busy,
                child: FilledButton(
                  onPressed: busy ? null : onRemove,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.danger,
                    foregroundColor: palette.surface,
                  ),
                  child: Text(item.isReply ? 'Remove reply' : 'Remove post'),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
