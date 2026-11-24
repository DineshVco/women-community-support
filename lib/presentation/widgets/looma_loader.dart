import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import 'looma_cat_blink.dart';

/// Full-screen loading: the Looma cat head on the left watches a yarn ball
/// roll slowly away across the floor and back (about 3 s a loop), turning
/// as it rolls, with a thin soft-pink thread trailing behind it. The cat
/// tilts its head about 6 degrees as the ball passes, and blinks now and
/// then. With Reduce motion it is a still picture. Screen readers hear
/// "Loading".
class LoomaLoader extends StatefulWidget {
  const LoomaLoader({super.key, this.label = 'Loading'});

  final String label;

  static const String ballAsset = 'assets/images/hero/yarn_ball.webp';

  static const Duration loop = Duration(milliseconds: 3000);

  /// The most the cat's head tilts (6 degrees).
  static const double maxTilt = 6 * math.pi / 180;

  /// The thread colour: soft pink, a little deeper on dark backgrounds.
  static const Color lightThread = Color(0xFFE8A9A4);
  static const Color darkThread = Color(0xFFC98C88);

  /// The whole picture: at most this wide, smaller on narrow screens.
  static const double maxWidth = 300;

  /// Where the ball is, 0 (by the cat) to 1 (far end), at time [t] (0-1 of
  /// the loop): out and back, easing at both ends.
  static double ballAt(double t) => 0.5 - 0.5 * math.cos(2 * math.pi * t);

  /// The cat's tilt for a ball at [p]: most as it passes the middle.
  static double tiltAt(double p) => maxTilt * math.sin(math.pi * p);

  @override
  State<LoomaLoader> createState() => _LoomaLoaderState();
}

class _LoomaLoaderState extends State<LoomaLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: LoomaLoader.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _loop
        ..stop()
        ..value = 0.5; // the ball resting in the middle
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final still = AppMotion.reduced(context);
    final thread = dark ? LoomaLoader.darkThread : LoomaLoader.lightThread;
    final shadow = Colors.black.withValues(alpha: dark ? 0.35 : 0.07);

    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = math.min(
              LoomaLoader.maxWidth,
              (box.maxWidth.isFinite ? box.maxWidth : LoomaLoader.maxWidth) -
                  32,
            );
            final catHeight = width * 0.46;
            final catWidth = catHeight * LoomaCatBlink.aspect;
            final ball = width * 0.17;
            final height = catHeight + 8;
            // The ball rolls on the floor from just right of the cat to the
            // right edge.
            final start = catWidth * 0.9;
            final end = width - ball;
            return SizedBox(
              key: const ValueKey('looma-loader'),
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) {
                  final p = still ? 0.5 : LoomaLoader.ballAt(_loop.value);
                  final x = start + (end - start) * p;
                  // Rolling: turned by the distance travelled / radius.
                  final turn = still ? 0.0 : (x - start) / (ball / 2);
                  final tilt = still ? 0.0 : LoomaLoader.tiltAt(p);
                  final floor = height - 4;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The thread, behind everything.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ThreadPainter(
                            from: Offset(catWidth * 0.78, floor - 6),
                            to: Offset(x + ball * 0.3, floor - ball * 0.22),
                            floor: floor,
                            color: thread,
                          ),
                        ),
                      ),
                      // A soft shadow under the ball.
                      Positioned(
                        left: x + ball * 0.1,
                        top: floor - 3,
                        child: Container(
                          width: ball * 0.8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: shadow,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x,
                        top: floor - ball,
                        child: Transform.rotate(
                          key: const ValueKey('yarn-ball'),
                          angle: turn,
                          child: Image.asset(
                            LoomaLoader.ballAsset,
                            width: ball,
                            height: ball,
                            cacheWidth:
                                (ball * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      // The cat, looking towards the ball.
                      Positioned(
                        left: 0,
                        bottom: 4,
                        child: Transform.rotate(
                          key: const ValueKey('loader-cat-tilt'),
                          angle: tilt,
                          alignment: Alignment.bottomCenter,
                          child: LoomaCatBlink(height: catHeight),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A thin, soft thread from the cat to the ball, sagging onto the floor.
class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({
    required this.from,
    required this.to,
    required this.floor,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final double floor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset((from.dx + to.dx) / 2, floor + 2);
    final path =
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.from != from || old.to != to || old.color != color;
}

/// The loader filling a screen (cream or dark background from the theme).
class LoomaLoadingScreen extends StatelessWidget {
  const LoomaLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: const Center(child: LoomaLoader()),
    );
  }
}
