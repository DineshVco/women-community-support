import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Shrinks its child a little while a finger is down (100 ms): 97% for
/// buttons, 98% for cards. It only listens, so taps still reach the button
/// inside. Nothing moves with Reduce motion.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;

  /// How small it gets while pressed.
  final double scale;

  /// The press scale for cards.
  static const double card = 0.98;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  static const Duration _duration = Duration(milliseconds: 100);
  bool _pressed = false;

  void _set(bool value) {
    // The finger can lift after the card has scrolled out of the list.
    if (!mounted || !widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !AppMotion.reduced(context) ? widget.scale : 1,
        duration: _duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
