import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'ios.dart' show barColor;
import 'quick_exit_button.dart';

/// The header of Discuss, Care and Me (and Get help): ONE row with the
/// title on the left and Quick exit on the right, 4 px under the status
/// bar. While scrolling, the title shrinks and fades out completely while a
/// blurred bar fades in behind Quick exit. With Reduce motion it switches
/// in one step.
///
/// If the title and the Quick exit label do not both fit (small phone,
/// large text), Quick exit shows just its icon, so nothing overlaps.
class LoomaHeader extends StatelessWidget {
  const LoomaHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  /// Space under the status bar.
  static const double topGap = 4;

  /// Title sizes: at the top, and once scrolled.
  static const double largeSize = 34;
  static const double smallSize = 20;

  /// The row is never shorter than a comfortable tap target.
  static const double minRow = 48;

  /// The rounded line under the title: 24 x 3 px, 4 px below it.
  static const Size accentSize = Size(24, 3);
  static const double accentSpace = 4 + 3;

  static double _lineHeight(TextScaler scaler, double size) =>
      scaler.scale(size) * 1.15;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaler = media.textScaler;
    final top = media.padding.top;
    // The title line plus its small underline accent.
    final largeRow = (_lineHeight(scaler, largeSize) + accentSpace).clamp(
      minRow,
      400.0,
    );
    final smallRow = _lineHeight(scaler, smallSize).clamp(minRow, largeRow);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        title: title,
        leading: leading,
        trailing: trailing,
        top: top,
        maxHeight: top + topGap + largeRow,
        minHeight: top + smallRow,
        reduceMotion: AppMotion.reduced(context),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.title,
    required this.leading,
    required this.trailing,
    required this.top,
    required this.maxHeight,
    required this.minHeight,
    required this.reduceMotion,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final double top;
  final double maxHeight;
  final double minHeight;
  final bool reduceMotion;

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final palette = context.palette;
    final range = maxHeight - minHeight;
    var t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    // Reduce motion: large or small, nothing in between.
    if (reduceMotion) t = t < 0.5 ? 0 : 1;
    final size = lerpDouble(LoomaHeader.largeSize, LoomaHeader.smallSize, t)!;
    // 1 at rest, 0 once 80% collapsed (and exactly 0 or 1 with Reduce
    // motion, because t is).
    final titleOpacity = (1 - t / 0.8).clamp(0.0, 1.0);
    final scaler = MediaQuery.textScalerOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The blurred bar, only once scrolled.
        if (t > 0)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: ColoredBox(
                color: barColor(context).withValues(alpha: 0.82 * t),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 0.5,
            color: palette.border.withValues(alpha: t),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            top + LoomaHeader.topGap * (1 - t),
            AppSpacing.screenHorizontal - 4,
            0,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // Decided at the large size, so it does not flicker.
              final titleWidth = _width(title, scaler);
              final room =
                  box.maxWidth - (leading == null ? 0 : 48) - AppSpacing.sm;
              final tight =
                  titleWidth +
                      AppSpacing.sm +
                      QuickExitButton.widthFor(scaler) >
                  room;
              final end =
                  trailing is QuickExitButton
                      ? QuickExitButton(iconOnly: tight)
                      : trailing;
              return Row(
                children: [
                  if (leading != null) leading!,
                  Expanded(
                    // Fully visible at rest at the top; fades out completely
                    // as the bar collapses (gone before it is fully small).
                    // Screen readers still have the page title.
                    child: Opacity(
                      key: const ValueKey('header-title'),
                      opacity: titleOpacity,
                      alwaysIncludeSemantics: true,
                      child: Semantics(
                        header: true,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  style: AppTypography.heading(
                                    size,
                                    palette.text,
                                    height: 1.1,
                                    letterSpacing: -0.5 * (1 - t),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // The small blush accent under the title.
                                Container(
                                  key: const ValueKey('title-accent'),
                                  width: LoomaHeader.accentSize.width,
                                  height: LoomaHeader.accentSize.height,
                                  decoration: BoxDecoration(
                                    color: palette.titleAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (end != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    end,
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static double _width(String title, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: AppTypography.heading(LoomaHeader.largeSize, Colors.black),
      ),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      title != old.title ||
      leading != old.leading ||
      trailing != old.trailing ||
      top != old.top ||
      maxHeight != old.maxHeight ||
      minHeight != old.minHeight ||
      reduceMotion != old.reduceMotion;
}
