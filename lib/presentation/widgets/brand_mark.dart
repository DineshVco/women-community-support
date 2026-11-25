import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// "Looma" in Newsreader with a small 4-point star at its top right.
/// 56 on onboarding, 26 in the app bar.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = AppTypography.wordmarkSmall});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.text;
    final star = size * 0.26;

    return Semantics(
      label: 'Looma',
      header: true,
      excludeSemantics: true,
      child: Padding(
        // Room for the star so it never overlaps neighbours.
        padding: EdgeInsets.only(right: star * 0.9, top: star * 0.3),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // A logo: it keeps its size with large text (it would break
            // into "Loo / ma" on a small phone otherwise).
            Text(
              'Looma',
              maxLines: 1,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: AppTypography.heading(
                size,
                color,
                height: 1.0,
                letterSpacing: -size * 0.01,
              ),
            ),
            Positioned(
              right: -star * 0.95,
              top: -star * 0.3,
              child: FourPointStar(size: star, color: context.palette.blush),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small sparkle: four points joined by inward curves.
class FourPointStar extends StatelessWidget {
  const FourPointStar({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _StarPainter(color));
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path()..moveTo(c.dx, c.dy - r);
    // Each point curves in toward the centre before the next point.
    for (var i = 1; i <= 4; i++) {
      final angle = -math.pi / 2 + i * math.pi / 2;
      final point = Offset(
        c.dx + r * math.cos(angle),
        c.dy + r * math.sin(angle),
      );
      path.quadraticBezierTo(c.dx, c.dy, point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.color != color;
}

/// A hand-drawn looking underline: a slightly curved 2 px line.
class HandDrawnUnderline extends StatelessWidget {
  const HandDrawnUnderline({
    super.key,
    required this.width,
    required this.color,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, 10),
        painter: _UnderlinePainter(color),
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path =
        Path()
          ..moveTo(0, h * 0.70)
          // Rises a little in the middle and ends slightly higher, like a pen
          // stroke drawn quickly from left to right.
          ..cubicTo(w * 0.30, h * 0.25, w * 0.65, h * 0.20, w, h * 0.45);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
