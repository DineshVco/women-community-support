import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Shrinks its child to 97% while a finger is down (100 ms), like iOS
/// buttons. It only listens, so taps still reach the button inside.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  static const Duration _duration = Duration(milliseconds: 100);
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !AppMotion.reduced(context) ? 0.97 : 1,
        duration: _duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
