import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';

/// The Looma girl-with-cat drawing, gently alive.
///
/// Three PNG layers (same 900 × 959 canvas, so they line up exactly):
///   looma_character.png  girl + cat
///   looma_heart.png      small heart (floats up and fades, loops)
///   looma_sparks.png     3 spark lines (soft blink)
/// Mug steam is drawn in code. The whole picture floats up and down a little.
///
/// With "reduce motion" on (or [animate] false) it is a still picture with
/// the heart and sparks fully visible. In dark mode it sits on a white
/// rounded card, because the drawing has dark lines.
class LoomaCharacter extends StatefulWidget {
  const LoomaCharacter({super.key, this.height = 220, this.animate = true});

  final double height;
  final bool animate;

  /// Width / height of the PNG canvas (900 x 959).
  static const double aspect = 900 / 959;

  static const String characterAsset = 'assets/images/looma_character.png';
  static const String heartAsset = 'assets/images/looma_heart.png';
  static const String sparksAsset = 'assets/images/looma_sparks.png';

  @override
  State<LoomaCharacter> createState() => _LoomaCharacterState();
}

class _LoomaCharacterState extends State<LoomaCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  bool get _moving => widget.animate && !AppMotion.reduced(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LoomaCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_moving) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = h * LoomaCharacter.aspect;
    // Decode at display size: three 900 px layers would waste memory.
    final cacheWidth = (w * MediaQuery.devicePixelRatioOf(context)).round();

    Image layer(String asset) => Image.asset(
      asset,
      width: w,
      height: h,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
    );

    // Built once per build, not once per frame: only the transforms and
    // opacities below change while animating.
    final character = layer(LoomaCharacter.characterAsset);
    final heart = layer(LoomaCharacter.heartAsset);
    final sparks = layer(LoomaCharacter.sparksAsset);

    final Widget picture;
    if (!_moving) {
      // Still picture: everything fully visible, no steam.
      picture = Stack(children: [character, heart, sparks]);
    } else {
      picture = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // Whole picture: slow float (2 cycles per 7 seconds = 3.5 s).
          final float = math.sin(t * 4 * math.pi) * h * 0.012;

          // Heart: rises a little and fades, 2 times per loop.
          final hp = (t * 2) % 1;
          final heartDy = -hp * h * 0.06;
          final heartOpacity = 0.3 + 0.7 * math.sin(hp * math.pi);

          // Sparks: soft blink.
          final sparkOpacity =
              0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 3));

          return Transform.translate(
            offset: Offset(0, float),
            child: Stack(
              children: [
                character,
                Transform.translate(
                  offset: Offset(0, heartDy),
                  child: Opacity(
                    opacity: heartOpacity.clamp(0.0, 1.0),
                    child: heart,
                  ),
                ),
                Opacity(opacity: sparkOpacity.clamp(0.0, 1.0), child: sparks),
                CustomPaint(
                  size: Size(w, h),
                  painter: _SteamPainter(progress: t),
                ),
              ],
            ),
          );
        },
      );
    }

    final Widget sized = Semantics(
      image: true,
      label: 'Drawing of a smiling woman holding a mug, with a sleeping cat',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(width: w, height: h, child: picture),
        ),
      ),
    );

    // Dark mode: the drawing's dark lines need a light card behind them.
    final Widget framed =
        Theme.of(context).brightness == Brightness.light
            ? sized
            : Container(
              padding: EdgeInsets.all(h * 0.05),
              decoration: BoxDecoration(
                color: AppPalette.illustrationCard,
                borderRadius: BorderRadius.circular(AppRadius.card + 8),
              ),
              child: sized,
            );

    // Soft blush glow behind the character (10% at the centre, fading out).
    // A fading circle looks like a blurred one but costs nothing per frame.
    final glow = context.palette.blush;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Positioned + OverflowBox: the glow spills past the picture without
        // changing the widget's size.
        Positioned.fill(
          child: IgnorePointer(
            child: OverflowBox(
              // min 0: otherwise the min can exceed the max (dark-mode card).
              minWidth: 0,
              minHeight: 0,
              maxWidth: w * 1.15,
              maxHeight: w * 1.15,
              child: Container(
                width: w * 1.15,
                height: w * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: 0.10),
                      glow.withValues(alpha: 0.06),
                      glow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
        framed,
      ],
    );
  }
}

/// Two thin wisps of steam above the mug.
class _SteamPainter extends CustomPainter {
  _SteamPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Mug opening is at about 45% across and 51% down the picture.
    final baseX = size.width * 0.45;
    final baseY = size.height * 0.505;

    for (var k = 0; k < 2; k++) {
      final p = (progress * 2 + k * 0.5) % 1;
      final dx = (k == 0 ? -1 : 1) * size.width * 0.012;
      final rise = p * size.height * 0.05;
      final x = baseX + (k == 0 ? -size.width * 0.025 : size.width * 0.025);
      final y = baseY - rise;

      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = size.width * 0.006
            // Always dark: in dark mode the drawing sits on a white card.
            ..color = const Color(
              0xFF111111,
            ).withValues(alpha: 0.35 * math.sin(p * math.pi));

      final path =
          Path()
            ..moveTo(x, y)
            ..cubicTo(
              x - dx,
              y - size.height * 0.035,
              x + dx,
              y - size.height * 0.06,
              x,
              y - size.height * 0.09,
            );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SteamPainter old) => old.progress != progress;
}
