import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a Quick exit disguise and guarantees a way back to Looma:
///
///  * [holdToReturn]: press and hold anywhere for 1 second. A raw pointer
///    Listener over the whole screen is used, NOT a gesture recogniser, so
///    scrolling lists can never swallow the hold. Moving the finger more
///    than a little (scrolling) cancels it.
///  * The phone's Back button does nothing here (going back would undo the
///    disguise, and closing the app would lose her place).
///  * Away from the app for more than [autoReturnAfter] (e.g. she put the
///    phone down): coming back opens Looma again by itself (with App lock
///    on, at the lock screen).
class DisguiseShell extends StatefulWidget {
  const DisguiseShell({
    super.key,
    required this.child,
    required this.onReturn,
    this.holdToReturn = true,
    this.clock,
  });

  final Widget child;
  final VoidCallback onReturn;
  final bool holdToReturn;

  /// For tests.
  final DateTime Function()? clock;

  static const Duration holdDuration = Duration(seconds: 1);
  static const Duration autoReturnAfter = Duration(minutes: 10);

  /// How far the finger may drift during the hold (logical pixels).
  static const double holdSlop = 24;

  @override
  State<DisguiseShell> createState() => _DisguiseShellState();
}

class _DisguiseShellState extends State<DisguiseShell>
    with WidgetsBindingObserver {
  int? _pointer;
  Offset? _start;
  Timer? _holdTimer;
  DateTime? _awaySince;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _awaySince ??= _now();
      case AppLifecycleState.resumed:
        final since = _awaySince;
        _awaySince = null;
        if (since != null &&
            _now().difference(since) > DisguiseShell.autoReturnAfter) {
          widget.onReturn();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _down(PointerDownEvent event) {
    if (!widget.holdToReturn) return;
    if (_pointer != null) {
      _cancelHold(); // a second finger: not a hold
      return;
    }
    _pointer = event.pointer;
    _start = event.position;
    _holdTimer = Timer(DisguiseShell.holdDuration, () {
      _pointer = null;
      HapticFeedback.lightImpact();
      widget.onReturn();
    });
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _start == null) return;
    if ((event.position - _start!).distance > DisguiseShell.holdSlop) {
      _cancelHold();
    }
  }

  void _end(PointerEvent event) {
    if (event.pointer == _pointer) _cancelHold();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointer = null;
    _start = null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        child: widget.child,
      ),
    );
  }
}

/// Counts quick taps; calls [onTriple] on the third tap within [window].
class TripleTap extends StatefulWidget {
  const TripleTap({super.key, required this.child, required this.onTriple});

  final Widget child;
  final VoidCallback onTriple;

  static const Duration window = Duration(milliseconds: 600);

  @override
  State<TripleTap> createState() => _TripleTapState();
}

class _TripleTapState extends State<TripleTap> {
  int _count = 0;
  DateTime? _last;

  void _tap() {
    final now = DateTime.now();
    final last = _last;
    _count =
        (last != null && now.difference(last) <= TripleTap.window)
            ? _count + 1
            : 1;
    _last = now;
    if (_count >= 3) {
      _count = 0;
      _last = null;
      HapticFeedback.lightImpact();
      widget.onTriple();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A raw tap counter (no double-tap recogniser, so no tap delay).
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (r) => r.onTap = _tap,
            ),
      },
      child: widget.child,
    );
  }
}
