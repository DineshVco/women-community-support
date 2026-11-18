import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/report.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/adaptive.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/press_scale.dart';
import '../widgets/ios.dart';
import 'post_detail_screen.dart';

/// Open reports, grouped by post. A moderator reads the post, then keeps it
/// or removes it. Either choice closes every open report on that post.
///
/// Only people with a `moderators/{uid}` document can load this list
/// (firestore.rules), so opening it as anyone else just shows an error.
class ModeratorScreen extends StatefulWidget {
  const ModeratorScreen({super.key});

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
      MaterialPageRoute<void>(
        builder:
            (_) => PostDetailScreen(postId: postId, showHiddenContent: true),
      ),
    );
  }

  Future<void> _decide(_ReportedPost item, {required bool remove}) async {
    if (remove) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove this post?',
        message:
            '“${item.title}” will be removed for everyone. The people '
            'who reported it will see that it was removed.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(item.postId));
    try {
      await _repo.resolvePostReports(postId: item.postId, removePost: remove);
      AppHaptics.medium();
      messenger.showSnackBar(
        SnackBar(
          content: Text(remove ? 'Post removed.' : 'Post kept and visible.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save the decision. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(item.postId));
    }
  }

  /// One entry per post, oldest report first, so nothing waits too long.
  List<_ReportedPost> _group(List<Report> reports) {
    final byPost = <String, _ReportedPost>{};
    for (final report in reports) {
      byPost
          .putIfAbsent(
            report.postId,
            () => _ReportedPost(
              postId: report.postId,
              title: report.postTitle,
              firstReportedAt: report.createdAt,
            ),
          )
          .reasons
          .add(report.reason);
    }
    return byPost.values.toList()
      ..sort((a, b) => a.firstReportedAt.compareTo(b.firstReportedAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: loomaNavBar(context, title: 'Report queue'),
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
                return const Center(child: CircularProgressIndicator());
              }

              final items = _group(snapshot.data!);
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
                  return _ReportedPostRow(
                    item: item,
                    busy: _busy.contains(item.postId),
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

class _ReportedPost {
  _ReportedPost({
    required this.postId,
    required this.title,
    required this.firstReportedAt,
  });

  final String postId;
  final String title;
  final DateTime firstReportedAt;
  final List<String> reasons = [];
}

class _ReportedPostRow extends StatelessWidget {
  const _ReportedPostRow({
    required this.item,
    required this.busy,
    required this.onRead,
    required this.onKeep,
    required this.onRemove,
  });

  final _ReportedPost item;
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
            item.title.isEmpty ? 'Untitled post' : item.title,
            style: theme.textTheme.titleMedium,
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
                child: const Text('Read post'),
              ),
              PressScale(
                enabled: !busy,
                child: OutlinedButton(
                  onPressed: busy ? null : onKeep,
                  child: const Text('Keep post'),
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
                  child: const Text('Remove post'),
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
