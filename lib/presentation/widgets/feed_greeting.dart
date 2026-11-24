import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/greeting.dart';
import '../../core/theme/app_icons.dart';
import 'fade_slide_in.dart';
import 'card_picture.dart';
import 'living_cat.dart';
import 'hero_card.dart';

/// The top of Discuss: a short painted card (by time of day, about 120 px)
/// with the greeting and one short line, and a small Looma cat peeking in
/// at its right edge. Counts and the starter-posts note live in the empty
/// state, not here.
class FeedGreeting extends StatelessWidget {
  const FeedGreeting({super.key, this.now, this.name});

  /// For tests; defaults to the phone's local time.
  final DateTime? now;

  /// Her first name (see greetingName), shown only here, on her phone.
  final String? name;

  static const double heroHeight = 120;

  /// Inside this small card, text grows at most this much (even with 2x
  /// text), so the greeting stays on one line and the card stays 120 px.
  static const double maxTextScale = 1.4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final time = now ?? DateTime.now();

    return Padding(
      // 8 px under the header row.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HeroCard(
            scene: HeroScene.forTime(time),
            minHeight: heroHeight,
            veil: HeroVeil.discuss,
            children: [
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: maxTextScale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handwritten (Caveat): one of only two places it is
                    // used. One line; a long name ends with "...".
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            greetingFor(time, name: name),
                            key: const ValueKey('greeting'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.script(28, palette.text),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(AppIcons.heart, size: 18, color: palette.text),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      greetingReassurance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Sits in the bottom right corner, over the painting a little.
          Positioned(
            right: 10,
            bottom: 10,
            child: PeekingCat(
              night: HeroScene.forTime(time) == HeroScene.night,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small Looma cat on a cream circle (dark lines on cream pass AA in
/// light and dark mode). Decorative: screen readers skip it. It fades up
/// once when it appears, then gently lives (blinks, bobs 2 px, sleepy at
/// night, waves when she posts); with Reduce motion it is simply there.
class PeekingCat extends StatelessWidget {
  const PeekingCat({super.key, this.night = false});

  /// Late at night the cat is sleepy.
  final bool night;

  static const double size = 60;

  /// The circle behind the drawing, the same in light and dark mode.
  static const Color halo = Color(0xFFFEF7F2);

  /// Late at night: the painted cat asleep on its cushion, this wide.
  static const double sleepWidth = 92;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (night) {
      return ExcludeSemantics(
        child: FadeSlideIn(
          distance: 6,
          child: SizedBox(
            key: const ValueKey('sleeping-cat'),
            width: sleepWidth,
            height: sleepWidth / CardPictures.catSleepAspect,
            child: Image.asset(
              CardPictures.catSleep,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder:
                  (_, _, _) =>
                      LivingCat(size: size - 12, night: true, listen: false),
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: FadeSlideIn(
        distance: 6,
        child: Container(
          key: const ValueKey('peeking-cat'),
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: halo,
            shape: BoxShape.circle,
            border: Border.all(color: palette.border),
          ),
          // Blinks, bobs, waves when she posts (see LivingCat).
          child: LivingCat(size: size - 12, night: night),
        ),
      ),
    );
  }
}
