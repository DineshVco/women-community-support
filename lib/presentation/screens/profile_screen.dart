import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/report.dart';
import '../../data/repositories/post_repository.dart';
import '../providers/theme_provider.dart';
import '../widgets/content_width.dart';
import '../widgets/quick_exit_button.dart';
import 'moderator_screen.dart';
import 'post_detail_screen.dart';

/// The "Me" tab: account, appearance, activity, reports, privacy, sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final PostRepository _repo;
  late Future<int> _postCount;
  late final Future<bool> _isModerator;
  late final Stream<List<Report>> _myReports;

  @override
  void initState() {
    super.initState();
    _repo = context.read<PostRepository>();
    _postCount = _repo.myPostCount();
    _isModerator = _repo.isModerator();
    _myReports = _repo.watchMyReports();
  }

  Future<void> _refresh() async {
    final next = _repo.myPostCount();
    setState(() => _postCount = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  Future<void> _signOut(bool isGuest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isGuest ? 'Sign out of guest account?' : 'Sign out?'),
        content: Text(
          isGuest
              ? 'Guest accounts cannot be recovered. If you sign out, you will '
                  'lose access to everything you posted, including the option '
                  'to delete it.'
              : 'You can sign back in at any time with your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isGuest
                ? TextButton.styleFrom(
                    foregroundColor: dialogContext.palette.danger,
                  )
                : null,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // AuthGate notices the change and shows the sign-in flow.
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        automaticallyImplyLeading: false,
        actions: const [QuickExitButton(), SizedBox(width: AppSpacing.sm)],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                // ───────── Account ─────────
                _Section(
                  title: 'Account',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest
                            ? 'Guest account'
                            : (user?.email ?? 'Signed in'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGuest
                            ? 'Tied to this device. No email address is stored.'
                            : 'Your email is only used to sign in. It is never '
                                'shown next to anything you write.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // ───────── Appearance ─────────
                _Section(
                  title: 'Appearance',
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {context.watch<ThemeProvider>().themeMode},
                      onSelectionChanged: (selection) => context
                          .read<ThemeProvider>()
                          .setThemeMode(selection.first),
                    ),
                  ),
                ),

                // ───────── Activity ─────────
                _Section(
                  title: 'Your activity',
                  child: FutureBuilder<int>(
                    future: _postCount,
                    builder: (context, snapshot) {
                      final String text;
                      if (snapshot.hasError) {
                        text = 'Could not load your post count. Pull down to '
                            'try again.';
                      } else if (!snapshot.hasData) {
                        text = 'Loading…';
                      } else {
                        final count = snapshot.data!;
                        text = count == 0
                            ? 'You have not started a discussion yet.'
                            : 'You have started $count '
                                '${count == 1 ? 'discussion' : 'discussions'}.';
                      }
                      return Text(text, style: theme.textTheme.bodyMedium);
                    },
                  ),
                ),

                // ───────── Reports ─────────
                _Section(
                  title: 'Your reports',
                  padChild: false,
                  child: StreamBuilder<List<Report>>(
                    stream: _myReports,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _SectionNote(
                          'Could not load your reports.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const _SectionNote('Loading…');
                      }
                      final reports = snapshot.data!;
                      if (reports.isEmpty) {
                        return const _SectionNote(
                          'You have not reported anything. If you report a '
                          'post, you can follow what happened to it here.',
                        );
                      }
                      return Column(
                        children: [
                          for (final report in reports)
                            _ReportRow(report: report),
                        ],
                      );
                    },
                  ),
                ),

                // ───────── Moderator ─────────
                FutureBuilder<bool>(
                  future: _isModerator,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return _Section(
                      title: 'Moderation',
                      padChild: false,
                      child: ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('Report queue'),
                        subtitle: const Text('Review reported posts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ModeratorScreen(),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ───────── Privacy ─────────
                _Section(
                  title: 'Your privacy',
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: palette.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Text(
                      'Other members and moderators never see who wrote a '
                      'post or reply. You appear under a random alias that '
                      'changes in every discussion.\n\n'
                      'To be honest about the limits: the people who run '
                      'HerCircle\'s database can technically link posts to '
                      'accounts. Avoid sharing names, places or details that '
                      'could identify you or others.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.primary,
                      ),
                    ),
                  ),
                ),

                // ───────── Sign out ─────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.md,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(isGuest),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group separated by a hairline.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.padChild = true,
  });

  final String title;
  final Widget child;

  /// False for children (like ListTiles) that already have side padding.
  final bool padChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const side = EdgeInsets.symmetric(
      horizontal: AppSpacing.screenHorizontal,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: side,
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          padChild ? Padding(padding: side, child: child) : child,
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
        ],
      ),
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(postId: report.postId),
        ),
      ),
    );
  }
}
