import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The 12 chat avatars: line-art cat faces on soft colour circles, in the
/// same black-line style as the Looma cat drawings. Drawn in code, so they
/// are sharp at any size and need no image files. No photos, ever.
///
/// firestore.rules accepts exactly these ids. Change both together.
class CatAvatars {
  CatAvatars._();

  static const List<String> ids = [
    'cat_01', 'cat_02', 'cat_03', 'cat_04', 'cat_05', 'cat_06', //
    'cat_07', 'cat_08', 'cat_09', 'cat_10', 'cat_11', 'cat_12',
  ];

  static const String fallback = 'cat_01';

  static bool isValid(String id) => ids.contains(id);

  static _Look _lookFor(String id) {
    final i = ids.indexOf(id);
    return _looks[i < 0 ? 0 : i];
  }

  // Background colour, eyes, extra detail.
  static const List<_Look> _looks = [
    _Look(Color(0xFFF4D6D2), _Eyes.closed, _Extra.stripes),
    _Look(Color(0xFFEFE3D0), _Eyes.open, _Extra.none),
    _Look(Color(0xFFD9E4D3), _Eyes.happy, _Extra.flower),
    _Look(Color(0xFFD6E2EE), _Eyes.closed, _Extra.glasses),
    _Look(Color(0xFFE2DAEC), _Eyes.wink, _Extra.bow),
    _Look(Color(0xFFF3EAC2), _Eyes.open, _Extra.stripes),
    _Look(Color(0xFFF6DCC8), _Eyes.happy, _Extra.heart),
    _Look(Color(0xFFD3EBE3), _Eyes.closed, _Extra.patch),
    _Look(Color(0xFFEED3DD), _Eyes.open, _Extra.bow),
    _Look(Color(0xFFE4E2DE), _Eyes.wink, _Extra.stripes),
    _Look(Color(0xFFDCD9F0), _Eyes.happy, _Extra.glasses),
    _Look(Color(0xFFF5E0BE), _Eyes.closed, _Extra.heart),
  ];
}

enum _Eyes { closed, open, happy, wink }

/// Eyes to draw instead of an avatar's own (the living cat blinks and is
/// sleepy at night).
enum CatEyes { open, closed, happy, wink }

enum _Extra { none, stripes, glasses, bow, heart, flower, patch }

class _Look {
  const _Look(this.background, this.eyes, this.extra);

  final Color background;
  final _Eyes eyes;
  final _Extra extra;
}

class CatAvatar extends StatelessWidget {
  const CatAvatar({super.key, required this.id, this.size = 48, this.eyes});

  final String id;
  final double size;

  /// Overrides the avatar's own eyes when set.
  final CatEyes? eyes;

  @override
  Widget build(BuildContext context) {
    final number = CatAvatars.ids.indexOf(id) + 1;
    return Semantics(
      image: true,
      label: 'Cat avatar ${number < 1 ? 1 : number}',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _CatPainter(_withEyesOf(CatAvatars._lookFor(id), eyes)),
        ),
      ),
    );
  }
}

_Look _withEyesOf(_Look look, CatEyes? eyes) =>
    eyes == null
        ? look
        : _Look(look.background, switch (eyes) {
          CatEyes.open => _Eyes.open,
          CatEyes.closed => _Eyes.closed,
          CatEyes.happy => _Eyes.happy,
          CatEyes.wink => _Eyes.wink,
        }, look.extra);

class _CatPainter extends CustomPainter {
  _CatPainter(this.look);

  final _Look look;

  static const Color _ink = Color(0xFF111111);
  static const Color _blush = Color(0xFFE9B8B3);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final line =
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * 0.03)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final white = Paint()..color = Colors.white;
    final ink = Paint()..color = _ink;

    // Background circle.
    canvas.drawCircle(p(0.5, 0.5), s / 2, Paint()..color = look.background);

    // Ears, then the head on top of their bases.
    for (final ear in [
      [p(0.27, 0.47), p(0.29, 0.17), p(0.46, 0.36)],
      [p(0.73, 0.47), p(0.71, 0.17), p(0.54, 0.36)],
    ]) {
      final path = Path()..addPolygon(ear, true);
      canvas
        ..drawPath(path, white)
        ..drawPath(path, line);
    }
    final head = Rect.fromCenter(
      center: p(0.5, 0.57),
      width: s * 0.58,
      height: s * 0.47,
    );
    canvas
      ..drawOval(head, white)
      ..drawOval(head, line);

    if (look.extra == _Extra.patch) {
      canvas.drawOval(
        Rect.fromCenter(
          center: p(0.61, 0.55),
          width: s * 0.16,
          height: s * 0.13,
        ),
        Paint()..color = const Color(0xFFDADADA),
      );
    }

    // Cheeks.
    final cheek = Paint()..color = _blush.withValues(alpha: 0.7);
    canvas
      ..drawCircle(p(0.34, 0.64), s * 0.035, cheek)
      ..drawCircle(p(0.66, 0.64), s * 0.035, cheek);

    // Eyes.
    void closedEye(double x) => canvas.drawPath(
      Path()
        ..moveTo(x * s - s * 0.045, 0.555 * s)
        ..quadraticBezierTo(x * s, 0.595 * s, x * s + s * 0.045, 0.555 * s),
      line,
    );
    void happyEye(double x) => canvas.drawPath(
      Path()
        ..moveTo(x * s - s * 0.045, 0.575 * s)
        ..quadraticBezierTo(x * s, 0.525 * s, x * s + s * 0.045, 0.575 * s),
      line,
    );
    void openEye(double x) => canvas.drawCircle(p(x, 0.56), s * 0.03, ink);

    switch (look.eyes) {
      case _Eyes.closed:
        closedEye(0.39);
        closedEye(0.61);
      case _Eyes.open:
        openEye(0.39);
        openEye(0.61);
      case _Eyes.happy:
        happyEye(0.39);
        happyEye(0.61);
      case _Eyes.wink:
        openEye(0.39);
        closedEye(0.61);
    }

    // Nose and mouth.
    canvas.drawPath(
      Path()
        ..addPolygon([p(0.475, 0.625), p(0.525, 0.625), p(0.5, 0.65)], true),
      ink,
    );
    final thin =
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * 0.022)
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(0.455 * s, 0.665 * s)
        ..quadraticBezierTo(0.4775 * s, 0.695 * s, 0.5 * s, 0.665 * s)
        ..quadraticBezierTo(0.5225 * s, 0.695 * s, 0.545 * s, 0.665 * s),
      thin,
    );

    // Whiskers.
    for (final w in [
      [p(0.14, 0.6), p(0.3, 0.625)],
      [p(0.15, 0.69), p(0.3, 0.665)],
      [p(0.86, 0.6), p(0.7, 0.625)],
      [p(0.85, 0.69), p(0.7, 0.665)],
    ]) {
      canvas.drawLine(w[0], w[1], thin);
    }

    // The extra detail.
    switch (look.extra) {
      case _Extra.none:
      case _Extra.patch:
        break;
      case _Extra.stripes:
        canvas
          ..drawLine(p(0.45, 0.345), p(0.46, 0.4), line)
          ..drawLine(p(0.5, 0.335), p(0.5, 0.395), line)
          ..drawLine(p(0.55, 0.345), p(0.54, 0.4), line);
      case _Extra.glasses:
        canvas
          ..drawCircle(p(0.39, 0.565), s * 0.075, line)
          ..drawCircle(p(0.61, 0.565), s * 0.075, line)
          ..drawLine(p(0.465, 0.56), p(0.535, 0.56), thin);
      case _Extra.bow:
        final bow = Paint()..color = _blush;
        final left =
            Path()
              ..addPolygon([p(0.66, 0.31), p(0.56, 0.25), p(0.57, 0.37)], true);
        final right =
            Path()
              ..addPolygon([p(0.66, 0.31), p(0.76, 0.25), p(0.75, 0.37)], true);
        for (final wing in [left, right]) {
          canvas
            ..drawPath(wing, bow)
            ..drawPath(wing, thin);
        }
        canvas
          ..drawCircle(p(0.66, 0.31), s * 0.03, bow)
          ..drawCircle(p(0.66, 0.31), s * 0.03, thin);
      case _Extra.heart:
        _heart(canvas, p(0.83, 0.25), s * 0.11, thin);
      case _Extra.flower:
        final petal = Paint()..color = Colors.white;
        final centre = p(0.3, 0.33);
        for (var k = 0; k < 5; k++) {
          final a = k * 2 * math.pi / 5 - math.pi / 2;
          final c = centre + Offset(math.cos(a), math.sin(a)) * s * 0.045;
          canvas
            ..drawCircle(c, s * 0.032, petal)
            ..drawCircle(c, s * 0.032, thin);
        }
        canvas.drawCircle(centre, s * 0.025, Paint()..color = _blush);
    }
  }

  void _heart(Canvas canvas, Offset c, double w, Paint paint) {
    final h = w * 0.9;
    final path =
        Path()
          ..moveTo(c.dx, c.dy + h * 0.45)
          ..cubicTo(
            c.dx - w * 0.75,
            c.dy - h * 0.05,
            c.dx - w * 0.35,
            c.dy - h * 0.65,
            c.dx,
            c.dy - h * 0.2,
          )
          ..cubicTo(
            c.dx + w * 0.35,
            c.dy - h * 0.65,
            c.dx + w * 0.75,
            c.dy - h * 0.05,
            c.dx,
            c.dy + h * 0.45,
          );
    canvas
      ..drawPath(path, Paint()..color = Colors.white)
      ..drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) => old.look != look;
}
