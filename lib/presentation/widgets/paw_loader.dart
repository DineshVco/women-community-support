import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

/// A small loader (about 48 px) for small loading spots: soft blush paw
/// prints appear one after another, walking up and to the right, then fade
/// and start again. Drawn (no picture). With Reduce motion the prints are
/// simply there, still. Screen readers hear "Loading".
class PawLoader extends StatefulWidget {
  const PawLoader({super.key, this.size = 48, this.label = 'Loading'});

  final double size;
  final String label;

  static const int prints = 4;
  static const Duration loop = Duration(milliseconds: 1600);

  /// How visible print [i] is at time [t] (0-1 of the loop): each appears
  /// in turn, stays, and all fade together at the end.
  static double opacityAt(int i, double t) {
    final appear = i / (prints + 1);
    if (t < appear) return 0;
    final fadeIn = ((t - appear) * (prints + 1) * 2).clamp(0.0, 1.0);
    final fadeOut = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
    return fadeIn * fadeOut;
  }

  @override
  State<PawLoader> createState() => _PawLoaderState();
}

class _PawLoaderState extends State<PawLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: PawLoader.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = AppMotion.reduced(context);
    final color = context.palette.blush;
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: SizedBox.square(
        key: const ValueKey('paw-loader'),
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder:
              (context, _) => CustomPaint(
                painter: _PawsPainter(
                  color: color,
                  // Still: every print shown, softly.
                  opacities: [
                    for (var i = 0; i < PawLoader.prints; i++)
                      still ? 0.8 : PawLoader.opacityAt(i, _loop.value),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _PawsPainter extends CustomPainter {
  const _PawsPainter({required this.color, required this.opacities});

  final Color color;
  final List<double> opacities;

  void _paw(Canvas canvas, Offset c, double s, double angle, Paint paint) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    // The pad, and four toes above it.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.18),
        width: s * 0.62,
        height: s * 0.5,
      ),
      paint,
    );
    for (final (x, y) in [
      (-0.34, -0.2),
      (-0.12, -0.38),
      (0.12, -0.38),
      (0.34, -0.2),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x * s, y * s),
          width: s * 0.22,
          height: s * 0.28,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width * 0.3;
    // Walking up and to the right, left and right feet in turn.
    const angle = math.pi / 5;
    for (var i = 0; i < opacities.length; i++) {
      final o = opacities[i];
      if (o <= 0) continue;
      final t = i / (opacities.length - 1);
      final side = i.isEven ? -1 : 1;
      final c = Offset(
        size.width * (0.2 + 0.6 * t) + side * s * 0.25,
        size.height * (0.82 - 0.64 * t) + side * s * 0.25,
      );
      _paw(canvas, c, s, angle, Paint()..color = color.withValues(alpha: o));
    }
  }

  @override
  bool shouldRepaint(_PawsPainter old) =>
      old.color != color || !_same(old.opacities, opacities);

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
