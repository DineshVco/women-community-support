import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Rises [distance] pixels while fading in, after [delay].
/// Shows the child immediately when [animate] is false or reduce-motion is on.
/// Use `distance: 0` for a plain fade.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
    this.distance = 8,
    this.duration = AppMotion.slow,
    this.curve = AppMotion.spring,
  });

  final Widget child;
  final Duration delay;
  final bool animate;

  /// How far (in logical pixels) the child rises.
  final double distance;
  final Duration duration;

  /// Curve for the movement. Opacity always uses a plain ease-out, because a
  /// spring would overshoot past fully visible.
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (!widget.animate || AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _rise,
        child: widget.child,
        builder:
            (context, child) => Transform.translate(
              offset: Offset(0, widget.distance * (1 - _rise.value)),
              child: child,
            ),
      ),
    );
  }
}

/// The Looma screen entrance: the character fades in and rises 12 px
/// (450 ms, ease-out), then the title, text and buttons fade in one after
/// another, 60 ms apart. Turned off by reduce motion (via [FadeSlideIn]).
class Entrance {
  const Entrance({this.enabled = true});

  /// False after the first frame, so widgets that appear later (an error
  /// message, a new line of text) show up without replaying the entrance.
  final bool enabled;

  static const Duration characterDuration = Duration(milliseconds: 450);
  static const Duration firstItemDelay = Duration(milliseconds: 300);
  static const Duration gap = Duration(milliseconds: 60);

  Widget character(Widget child) => FadeSlideIn(
    animate: enabled,
    distance: 12,
    duration: characterDuration,
    curve: Curves.easeOutCubic,
    child: child,
  );

  /// Wraps each item in a fade, 60 ms apart. Empty spacers are left alone.
  List<Widget> items(List<Widget> children) {
    var i = 0;
    return [
      for (final child in children)
        if ((child is SizedBox && child.child == null) || child is Spacer)
          child
        else
          FadeSlideIn(
            animate: enabled,
            delay: firstItemDelay + gap * i++,
            distance: 0,
            duration: AppMotion.slow,
            child: child,
          ),
    ];
  }
}

/// Gives a screen's State an [entrance] that plays only on the first frame.
mixin EntranceOnce<T extends StatefulWidget> on State<T> {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _entered = true);
  }

  Entrance get entrance => Entrance(enabled: !_entered);
}

/// AnimatedSize that respects Reduce motion: the size just changes. (An
/// AnimatedSize with a zero duration trips a Flutter layout assertion, so
/// it is left out entirely.)
class GentleSize extends StatelessWidget {
  const GentleSize({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.curve = AppMotion.enter,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}
