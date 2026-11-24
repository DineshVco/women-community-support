import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'card_picture.dart';
import 'fade_slide_in.dart';
import 'feed_greeting.dart' show PeekingCat;
import 'floating_illustration.dart';
import 'living_cat.dart';
import 'looma_button.dart';
import 'looma_character.dart';

/// Used for empty lists and error messages: a picture, a title, one line of
/// text and an optional button. The picture is the Looma character, or a
/// cat drawing when [illustration] is given (e.g. [LoomaCats.heart]).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showCharacter = true,
    this.illustration,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Off where space is tight.
  final bool showCharacter;

  /// A cat drawing asset to show instead of the girl with the cat.
  final String? illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const entrance = Entrance();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCharacter) ...[
            if (illustration != null)
              // Has its own fade-and-rise entrance and gentle float.
              FloatingIllustration(asset: illustration!, height: 140)
            else
              entrance.character(const LoomaCharacter(height: 130)),
            const SizedBox(height: AppSpacing.lg),
          ],
          ...entrance.items([
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              LoomaButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                showArrow: false,
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

/// An empty list: the painted cat asleep on its cushion and one warm line,
/// with an optional button.
class CatEmptyState extends StatelessWidget {
  const CatEmptyState({
    super.key,
    required this.line,
    this.actionLabel,
    this.onAction,
    this.picture = CardPictures.catSleep,
    this.pictureAspect = CardPictures.catSleepAspect,
  });

  final String line;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The painted picture: the sleeping cat, or e.g. the yarn ball.
  final String picture;
  final double pictureAspect;

  /// How wide the sleeping cat is drawn.
  static const double catWidth = 168;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                key: const ValueKey('empty-cat'),
                width: catWidth,
                height: catWidth / pictureAspect,
                child: Image.asset(
                  picture,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  // If it cannot load, the drawn cat instead.
                  errorBuilder:
                      (_, _, _) => Container(
                        decoration: BoxDecoration(
                          color: PeekingCat.halo,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.border),
                        ),
                        child: const LivingCat(size: 72, listen: false),
                      ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              line,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: palette.text),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              LoomaButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                showArrow: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
