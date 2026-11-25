import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/haptics.dart';
import 'press_scale.dart';
import '../../core/theme/app_icons.dart';

/// Full-width Looma buttons.
///  * [LoomaButton.primary]: black fill, white text, then an arrow "→".
///  * [LoomaButton.outline]: 1.5 px black border, black text, no fill.
/// Both shrink slightly while pressed and give a light haptic.
/// [success] swaps the label for a tick (e.g. right after signing in).
class LoomaButton extends StatelessWidget {
  const LoomaButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
    this.success = false,
  }) : _outline = false;

  const LoomaButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = false,
    this.success = false,
  }) : _outline = true;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final bool success;
  final bool _outline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null && !loading && !success;
    final foreground = _outline ? palette.text : palette.onPrimary;

    final VoidCallback? tap =
        enabled
            ? () {
              AppHaptics.light();
              onPressed!();
            }
            : null;

    final Widget content =
        success
            ? Icon(
              AppIcons.check,
              key: const ValueKey('success'),
              size: 24,
              color: foreground,
              semanticLabel: 'Done',
            )
            : loading
            ? SizedBox(
              key: const ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _outline ? palette.text : palette.textMuted,
              ),
            )
            : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                // Up to two lines with large text on a small phone (the
                // button grows taller), so the whole label is readable.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.arrowRight, size: 20, color: foreground),
                ],
              ],
            );

    // Label, spinner and tick cross-fade (the tick also pops in).
    final animated = AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.fast),
      transitionBuilder:
          (child, animation) => FadeTransition(
            opacity: animation,
            child:
                child.key == const ValueKey('success')
                    ? ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: AppMotion.springPop,
                      ),
                      child: child,
                    )
                    : child,
          ),
      child: content,
    );

    // While showing the tick the button keeps its normal colours (a
    // disabled button would turn grey) but ignores taps.
    final VoidCallback? onTap = success ? () {} : tap;

    return IgnorePointer(
      ignoring: success,
      child: PressScale(
        enabled: enabled,
        child: SizedBox(
          width: double.infinity,
          child:
              _outline
                  ? OutlinedButton(onPressed: onTap, child: animated)
                  : FilledButton(onPressed: onTap, child: animated),
        ),
      ),
    );
  }
}
