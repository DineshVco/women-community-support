import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/greeting.dart';
import '../../data/models/post.dart';
import '../providers/app_settings.dart';
import 'hero_card.dart';
import 'team_badge.dart';

/// A painted card (by time of day) with "Good evening" and how many
/// discussions started in the last 24 hours.
/// Inside it, a note while the Looma Team starter posts are in the feed.
/// [posts] comes from the live feed, so the count updates by itself.
class FeedGreeting extends StatelessWidget {
  const FeedGreeting({super.key, required this.posts, this.onWrite});

  /// Null while the feed is still loading.
  final List<Post>? posts;

  /// Tapping the painted card opens "Write a post".
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final String subline;
    final list = posts;
    if (AppSettings.gentleOf(context)) {
      // Gentle mode: no counting.
      subline = 'Take your time. Read, share, or just rest here.';
    } else if (list == null) {
      subline = 'Catching up on the latest…';
    } else {
      final count = countRecent(list.map((p) => p.timestamp));
      subline = switch (count) {
        0 => 'No new discussions today yet. Yours could be the first.',
        1 => '1 new discussion in the last 24 hours.',
        _ => '$count new discussions in the last 24 hours.',
      };
    }

    final now = DateTime.now();
    final starters = list != null && list.any((p) => LoomaTeam.isTeam(p.alias));
    return Padding(
      // 8 px under the header row.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The painted card changes with the time of day.
          HeroCard(
            scene: HeroScene.forTime(now),
            actionLabel: 'Write a post',
            onTap: onWrite,
            children: [
              // Handwritten (Caveat): one of only two places it is used.
              Text(
                greetingFor(now),
                style: AppTypography.script(32, palette.text),
              ),
              const SizedBox(height: 2),
              Text(
                greetingReassurance,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.text,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Fades between messages when the live count changes.
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.medium),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                layoutBuilder:
                    (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, if (current != null) current],
                    ),
                child: Semantics(
                  liveRegion: true,
                  key: ValueKey(subline),
                  child: Text(
                    subline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.text,
                    ),
                  ),
                ),
              ),
              // Only while the Looma Team starter posts are in the feed.
              if (starters) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  LoomaTeam.starterLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.text,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
