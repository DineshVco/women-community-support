import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/content_library.dart';
import '../../data/help_lines.dart';
import '../../data/today_for_you.dart';
import 'looma_card.dart';

/// "Today for you" on Care: one suggestion that fits the time of day (from
/// content/today_for_you.json), the same all through the slot. Late at
/// night the card is quieter. Tapping it opens the suggestion.
class TodayForYouCard extends StatelessWidget {
  const TodayForYouCard({
    super.key,
    required this.onOpen,
    this.now,
    this.library,
    this.includeDrafts,
  });

  final ValueChanged<TodaySuggestion> onOpen;

  /// For tests; defaults to the phone's local time.
  final DateTime? now;

  /// For tests; defaults to the bundled content.
  final ContentLibrary? library;

  /// For tests; defaults to drafts in debug builds only.
  final bool? includeDrafts;

  static const String heading = 'Today for you';

  static IconData iconFor(TodaySlot slot) => switch (slot) {
    TodaySlot.morning => AppIcons.morning,
    TodaySlot.afternoon => AppIcons.afternoon,
    TodaySlot.evening => AppIcons.evening,
    TodaySlot.night => AppIcons.night,
  };

  @override
  Widget build(BuildContext context) {
    if (library != null) return _build(context, library!);
    return WithContent(builder: _build);
  }

  Widget _build(BuildContext context, ContentLibrary library) {
    final time = now ?? DateTime.now();
    final suggestion =
        includeDrafts == null
            ? library.todayForYou.pick(time)
            : library.todayForYou.pick(time, includeDrafts: includeDrafts!);
    if (suggestion == null) return const SizedBox.shrink();

    final palette = context.palette;
    final slot = TodaySlot.forTime(time);
    final night = slot == TodaySlot.night;
    final tint = switch (slot) {
      TodaySlot.morning => palette.categoryFill('education'), // sand
      TodaySlot.afternoon => palette.categoryFill('health_wellness'), // sage
      TodaySlot.evening => palette.categoryFill('career_development'),
      TodaySlot.night => palette.surface, // quieter
    };

    return Semantics(
      hint: suggestion.actionLabel,
      child: LoomaCard(
        key: ValueKey('today-${slot.name}'),
        // Late at night: a plain soft card, no colour.
        color: night ? palette.softFill : null,
        onTap: () => onOpen(suggestion),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(iconFor(slot), size: 20, color: palette.text),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$heading · ${slot.label}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.title,
                    style: AppTypography.heading(
                      19,
                      palette.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          suggestion.actionLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        AppIcons.chevronRight,
                        size: 14,
                        color: palette.text,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
