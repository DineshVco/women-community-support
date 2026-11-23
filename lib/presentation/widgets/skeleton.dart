import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import 'looma_card.dart';

/// Loading placeholders in the same shape as the real cards, with a soft
/// shimmer passing over them (none with Reduce motion). Screen readers hear
/// one "Loading" instead of the empty shapes.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({
    super.key,
    required this.child,
    this.label = 'Loading',
  });

  final Widget child;
  final String label;

  static const Duration period = Duration(milliseconds: 1400);

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SkeletonShimmer.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shapes = ExcludeSemantics(child: widget.child);
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child:
          AppMotion.reduced(context)
              ? shapes
              : AnimatedBuilder(
                animation: _controller,
                child: shapes,
                builder: (context, child) {
                  final t = _controller.value;
                  // A soft band of light sweeps from left to right.
                  return ShaderMask(
                    key: const ValueKey('skeleton-shimmer'),
                    blendMode: BlendMode.srcATop,
                    shaderCallback:
                        (rect) => LinearGradient(
                          begin: Alignment(-1.5 + 3 * t, -0.3),
                          end: Alignment(-0.5 + 3 * t, 0.3),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: dark ? 0.06 : 0.45),
                            Colors.transparent,
                          ],
                        ).createShader(rect),
                    child: child,
                  );
                },
              ),
    );
  }
}

/// One rounded grey block.
class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.softFill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// The shape of a PostCard: category pill, two title lines, two preview
/// lines, then the avatar, alias and counts.
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('skeleton-post'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: LoomaCard.gap / 2,
      ),
      child: LoomaCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Bone(width: 78, height: 22, radius: 999),
                const SizedBox(height: 10),
                _Bone(width: w * 0.85, height: 20),
                const SizedBox(height: 8),
                _Bone(width: w * 0.55, height: 20),
                const SizedBox(height: 12),
                _Bone(width: w * 0.95, height: 12),
                const SizedBox(height: 7),
                _Bone(width: w * 0.7, height: 12),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    _Bone(width: 32, height: 32, radius: 16),
                    SizedBox(width: AppSpacing.sm),
                    _Bone(width: 96, height: 12),
                    Spacer(),
                    _Bone(width: 30, height: 12),
                    SizedBox(width: AppSpacing.md),
                    _Bone(width: 30, height: 12),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A few post skeletons in a column (for lists that load as a whole).
class SkeletonPostList extends StatelessWidget {
  const SkeletonPostList({super.key, this.count = 3, this.label = 'Loading'});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < count; i++) const SkeletonPostCard(),
        ],
      ),
    );
  }
}

/// The shape of a reply: alias line, then two lines of text.
class SkeletonReply extends StatelessWidget {
  const SkeletonReply({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('skeleton-reply'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      child: LayoutBuilder(
        builder:
            (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Bone(width: 110, height: 14),
                const SizedBox(height: 8),
                _Bone(width: box.maxWidth * 0.9, height: 12),
                const SizedBox(height: 6),
                _Bone(width: box.maxWidth * 0.6, height: 12),
              ],
            ),
      ),
    );
  }
}
