import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import 'transient_overlays.dart';
import '../../core/theme/app_icons.dart';

/// A small, soft burst of blush hearts that rise and fade (800 ms).
/// Shown once, after her very first post. Never blocks taps.
/// With reduce motion on, nothing is shown.
void showHeartBurst(BuildContext context) {
  if (AppMotion.reduced(context)) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => HeartBurst(onDone: () => TransientOverlays.remove(entry)),
  );
  TransientOverlays.insert(overlay, entry);
}

class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key, required this.onDone});

  final VoidCallback onDone;

  static const Duration duration = Duration(milliseconds: 800);
  static const int count = 7;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HeartBurst.duration,
  );

  // Fixed spread (no randomness), so it looks the same every time:
  // horizontal offset, how high it rises, size, start delay (0–1).
  static const _hearts = [
    (dx: -70.0, rise: 120.0, size: 18.0, delay: 0.00),
    (dx: -38.0, rise: 160.0, size: 24.0, delay: 0.08),
    (dx: -12.0, rise: 135.0, size: 16.0, delay: 0.15),
    (dx: 10.0, rise: 175.0, size: 22.0, delay: 0.02),
    (dx: 34.0, rise: 125.0, size: 15.0, delay: 0.12),
    (dx: 58.0, rise: 150.0, size: 20.0, delay: 0.05),
    (dx: 82.0, rise: 110.0, size: 14.0, delay: 0.18),
  ];

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.palette.blush;
    final size = MediaQuery.sizeOf(context);
    // Starts a little below the middle of the screen.
    final origin = Offset(size.width / 2, size.height * 0.58);

    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                for (final heart in _hearts)
                  _heart(heart, origin, color, _controller.value),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heart(
    ({double dx, double rise, double size, double delay}) heart,
    Offset origin,
    Color color,
    double t,
  ) {
    // Each heart has its own slightly delayed 0→1 progress.
    final p = ((t - heart.delay) / (1 - heart.delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(p);
    // Fades in quickly, then out.
    final opacity = math.sin(p * math.pi).clamp(0.0, 1.0);
    // Small sideways sway while rising.
    final sway = math.sin(p * math.pi * 2) * 6;

    return Positioned(
      left: origin.dx + heart.dx + sway - heart.size / 2,
      top: origin.dy - heart.rise * eased - heart.size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.6 + 0.4 * eased,
          child: Icon(AppIcons.heartFilled, size: heart.size, color: color),
        ),
      ),
    );
  }
}
