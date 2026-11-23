import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import 'press_scale.dart';

/// The Looma card: a raised surface with a 1 px warm border, 20 px corners
/// and a soft two-layer shadow (light mode; in dark mode the border and the
/// lighter surface do the lifting). Tappable cards shrink to 98% while
/// pressed (not with Reduce motion) and give a light haptic.
class LoomaCard extends StatelessWidget {
  const LoomaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Defaults to the surface colour.
  final Color? color;

  /// Paints over [color] (e.g. the profile card's blush to cream).
  final Gradient? gradient;

  /// The gap between cards in a list.
  static const double gap = 12;

  /// The soft shadow under cards in light mode.
  static List<BoxShadow> shadowFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? const []
          : const [
            BoxShadow(
              color: Color(0x0A3B2A22), // 4%, warm
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
            BoxShadow(
              color: Color(0x0F3B2A22), // 6%, warm
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.card);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: palette.border),
        boxShadow: shadowFor(Theme.of(context).brightness),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child:
            onTap == null
                ? Padding(padding: padding, child: child)
                : InkWell(
                  onTap: () {
                    AppHaptics.light();
                    onTap!();
                  },
                  child: Padding(padding: padding, child: child),
                ),
      ),
    );
    if (onTap == null) return card;
    return PressScale(scale: PressScale.card, child: card);
  }
}
