import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../data/models/report.dart';
import '../../../data/repositories/post_repository.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../post_detail_screen.dart';
import '../../widgets/ios.dart';

/// Reports she made, and what happened to each.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final Stream<List<Report>> _reports =
      context.read<PostRepository>().watchMyReports();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: loomaNavBar(context, title: 'My reports'),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: StreamBuilder<List<Report>>(
            stream: _reports,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  title: 'Could not load your reports',
                  message: 'Check your internet connection and try again.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final reports = snapshot.data!;
              if (reports.isEmpty) {
                return const EmptyState(
                  title: 'No reports',
                  message:
                      'If you report a post, you can follow what happened to '
                      'it here.',
                );
              }
              return ListView(
                children: [for (final r in reports) _ReportRow(report: r)],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final (String outcome, Color color) = switch (report.status) {
      'dismissed' => ('Reviewed: post kept', palette.textSecondary),
      'removed' => ('Reviewed: post removed', palette.success),
      _ => ('Waiting for review', palette.warning),
    };

    return ListTile(
      title: Text(
        report.postTitle.isEmpty ? 'Untitled post' : report.postTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${report.reason}  ·  ${timeAgo(report.createdAt)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        outcome,
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PostDetailScreen(postId: report.postId),
            ),
          ),
    );
  }
}
