import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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

/// An empty list: the Looma cat (gently alive, still with Reduce motion) and
/// one warm line, with an optional button.
class CatEmptyState extends StatelessWidget {
  const CatEmptyState({
    super.key,
    required this.line,
    this.actionLabel,
    this.onAction,
  });

  final String line;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double catSize = 96;

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
              child: Container(
                key: const ValueKey('empty-cat'),
                width: catSize,
                height: catSize,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // Cream in both modes: the drawing has dark lines.
                  color: PeekingCat.halo,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.border),
                ),
                child: const LivingCat(size: catSize - 22, listen: false),
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
