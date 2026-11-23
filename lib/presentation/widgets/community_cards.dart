import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../../data/content_library.dart';
import '../../data/help_lines.dart';
import '../../data/models/community.dart';
import '../screens/care/guides_screen.dart';
import 'adaptive.dart';
import '../../core/theme/app_icons.dart';

/// The soft colours of the spec, used only for small dots and labels.
Color themeDotColor(String colorKey) => switch (colorKey) {
  'sage' => const Color(0xFFBFD0C1),
  'sand' => const Color(0xFFE6D3B3),
  'lavender' => const Color(0xFFCFC9DB),
  _ => const Color(0xFFE9B8B3), // blush
};

const _side = EdgeInsets.fromLTRB(
  AppSpacing.screenHorizontal,
  AppSpacing.lg,
  AppSpacing.screenHorizontal,
  0,
);

/// The pinned Small wins card at the top of Discuss. No counts at all: it
/// is a gentle place, not a contest.
class SmallWinsCard extends StatelessWidget {
  const SmallWinsCard({super.key, required this.thread, required this.onOpen});

  final SmallWinsThread thread;
  final VoidCallback onOpen;

  static const String line =
      'A gentle place to share a small good thing. No likes, no counts.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: _side,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            AppHaptics.light();
            onOpen();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.pin, size: 14, color: palette.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'SMALL WINS · THIS WEEK',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(thread.title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onOpen,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(AppIcons.chevronRight, size: 16),
                    label: const Text('Share a small win'),
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

/// A small banner while a themed week is running (themes/current). Tapping
/// it lists that week's guides from content/guides.json.
class ThemedWeekBanner extends StatelessWidget {
  const ThemedWeekBanner({super.key, required this.week});

  final ThemedWeek week;

  List<Guide> _guides(ContentLibrary library) {
    final visible = {for (final g in library.visibleGuides()) g.id: g};
    return [
      for (final id in week.guideIds)
        if (visible[id] != null) visible[id]!,
    ];
  }

  Future<void> _open(BuildContext context, List<Guide> guides) async {
    AppHaptics.light();
    final picked = await showOptionsSheet<Guide>(
      context,
      title: week.title,
      message: 'Guides for this week',
      options: [for (final g in guides) SheetOption(value: g, label: g.title)],
    );
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => GuideDetailScreen(
              guide: picked,
              bookmarks: context.read<GuideBookmarks>(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return WithContent(
      builder: (context, library) {
        final guides = _guides(library);
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: themeDotColor(week.colorKey),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WEEK',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(week.title, style: theme.textTheme.titleSmall),
                  if (week.subtitle.isNotEmpty)
                    Text(
                      week.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (guides.isNotEmpty)
              Icon(AppIcons.chevronRight, size: 16, color: palette.textMuted),
          ],
        );
        return Padding(
          padding: _side,
          child: Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: guides.isEmpty ? null : () => _open(context, guides),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}
