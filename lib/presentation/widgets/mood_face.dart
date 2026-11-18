import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/mood.dart';

/// A line-art cat face for each mood (same style as the avatars), on the
/// mood's soft colour. Drawn in code.
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.mood, this.size = 56});

  final Mood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _MoodPainter(mood));
  }
}

class _MoodPainter extends CustomPainter {
  _MoodPainter(this.mood);

  final Mood mood;

  static const Color _ink = Color(0xFF111111);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final line =
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * 0.035)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final white = Paint()..color = Colors.white;

    canvas.drawCircle(p(0.5, 0.5), s / 2, Paint()..color = mood.dot);

    for (final ear in [
      [p(0.27, 0.47), p(0.29, 0.18), p(0.46, 0.36)],
      [p(0.73, 0.47), p(0.71, 0.18), p(0.54, 0.36)],
    ]) {
      final path = Path()..addPolygon(ear, true);
      canvas
        ..drawPath(path, white)
        ..drawPath(path, line);
    }
    final head = Rect.fromCenter(
      center: p(0.5, 0.58),
      width: s * 0.6,
      height: s * 0.48,
    );
    canvas
      ..drawOval(head, white)
      ..drawOval(head, line);

    void arc(double x, double y, double lift) => canvas.drawPath(
      Path()
        ..moveTo((x - 0.05) * s, y * s)
        ..quadraticBezierTo(x * s, (y + lift) * s, (x + 0.05) * s, y * s),
      line,
    );
    void dot(double x, double y) =>
        canvas.drawCircle(p(x, y), s * 0.03, Paint()..color = _ink);

    // Eyes.
    switch (mood) {
      case Mood.great:
      case Mood.good:
        arc(0.39, 0.57, -0.05); // happy ^ ^
        arc(0.61, 0.57, -0.05);
      case Mood.okay:
        dot(0.39, 0.56);
        dot(0.61, 0.56);
      case Mood.low:
        arc(0.39, 0.55, 0.04); // closed, down
        arc(0.61, 0.55, 0.04);
      case Mood.rough:
        canvas
          // Tired and sad (inner ends up), never angry.
          ..drawLine(p(0.35, 0.575), p(0.43, 0.545), line)
          ..drawLine(p(0.65, 0.575), p(0.57, 0.545), line);
    }

    // Mouth.
    switch (mood) {
      case Mood.great:
        final mouth =
            Path()
              ..moveTo(0.43 * s, 0.66 * s)
              ..quadraticBezierTo(0.5 * s, 0.76 * s, 0.57 * s, 0.66 * s)
              ..close();
        canvas
          ..drawPath(mouth, Paint()..color = _ink)
          ..drawPath(mouth, line);
      case Mood.good:
        arc(0.5, 0.67, 0.05);
      case Mood.okay:
        canvas.drawLine(p(0.45, 0.69), p(0.55, 0.69), line);
      case Mood.low:
        arc(0.5, 0.71, -0.03);
      case Mood.rough:
        arc(0.5, 0.72, -0.05);
    }

    // Soft cheeks on the happier faces.
    if (mood == Mood.great || mood == Mood.good) {
      final cheek = Paint()..color = const Color(0xFFE9B8B3);
      canvas
        ..drawCircle(p(0.33, 0.65), s * 0.035, cheek)
        ..drawCircle(p(0.67, 0.65), s * 0.035, cheek);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodPainter old) => old.mood != mood;
}
