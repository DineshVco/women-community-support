import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// The painted Looma cat head. It shows the open-eyed frame and, at random
/// moments 3 to 5 seconds apart, cross-fades to the closed-eyed frame and
/// back (about 150 ms): a blink.
///
/// It stays still (open eyes, no timers) with Reduce motion, while its
/// screen is not visible (another page on top, another tab), while the app
/// is in the background, and when another blinking cat is on screen: only
/// the newest one blinks, so there is only ever one animated cat.
class LoomaCatBlink extends StatefulWidget {
  const LoomaCatBlink({super.key, this.height = 120, this.random});

  final double height;

  /// For tests: a seeded random for the blink intervals.
  final math.Random? random;

  static const String openAsset = 'assets/images/hero/looma_cat_open.webp';
  static const String closedAsset = 'assets/images/hero/looma_cat_closed.webp';

  /// Width / height of the frames.
  static const double aspect = 600 / 755;

  static const Duration blink = Duration(milliseconds: 150);
  static const Duration minGap = Duration(seconds: 3);
  static const Duration maxGap = Duration(seconds: 5);

  /// The cats on screen; only the last one blinks.
  static final List<_LoomaCatBlinkState> _onScreen = [];

  /// How many blink timers are waiting (for tests).
  @visibleForTesting
  static int get pendingTimers =>
      _onScreen.where((s) => s._next?.isActive ?? false).length;

  @override
  State<LoomaCatBlink> createState() => _LoomaCatBlinkState();
}

class _LoomaCatBlinkState extends State<LoomaCatBlink>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: LoomaCatBlink.blink,
  );
  late final math.Random _random = widget.random ?? math.Random();
  Timer? _next;
  bool _visible = true;
  bool _still = false;
  bool _foreground = true;

  bool get _isTop =>
      LoomaCatBlink._onScreen.isNotEmpty &&
      identical(LoomaCatBlink._onScreen.last, this);

  bool get _shouldBlink => _visible && !_still && _foreground && _isTop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final previous =
        LoomaCatBlink._onScreen.isEmpty ? null : LoomaCatBlink._onScreen.last;
    LoomaCatBlink._onScreen.add(this);
    // The older cat stops blinking (after this frame: not while building).
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous._update());
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode is off when the screen is not visible (covered by another
    // page, or an inactive tab).
    _visible = TickerMode.of(context);
    _still = AppMotion.reduced(context);
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  /// Starts or stops the blinking to match the current state.
  void _update() {
    if (!mounted) return;
    if (_shouldBlink) {
      if (!(_next?.isActive ?? false) && !_blink.isAnimating) _schedule();
    } else {
      _next?.cancel();
      _next = null;
      _blink
        ..stop()
        ..value = 0;
    }
  }

  void _schedule() {
    final min = LoomaCatBlink.minGap.inMilliseconds;
    final spread = LoomaCatBlink.maxGap.inMilliseconds - min;
    _next = Timer(
      Duration(milliseconds: min + _random.nextInt(spread + 1)),
      () {
        _next = null;
        if (!mounted || !_shouldBlink) return;
        _blink.forward(from: 0).whenCompleteOrCancel(() {
          if (mounted) _update();
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _next?.cancel();
    _next = null;
    final wasTop = _isTop;
    LoomaCatBlink._onScreen.remove(this);
    _blink.dispose();
    if (wasTop && LoomaCatBlink._onScreen.isNotEmpty) {
      // The cat underneath may blink again.
      final below = LoomaCatBlink._onScreen.last;
      WidgetsBinding.instance.addPostFrameCallback((_) => below._update());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = h * LoomaCatBlink.aspect;
    final cache = (w * MediaQuery.devicePixelRatioOf(context)).round();
    Widget frame(String asset) => Image.asset(
      asset,
      width: w,
      height: h,
      fit: BoxFit.contain,
      cacheWidth: cache,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            frame(LoomaCatBlink.openAsset),
            // Closed eyes fade in and out again: 0 → 1 → 0.
            AnimatedBuilder(
              animation: _blink,
              builder: (context, child) {
                final t = _blink.value;
                final closed = 1 - (2 * t - 1).abs();
                return Opacity(
                  key: const ValueKey('cat-closed-eyes'),
                  opacity: _blink.isAnimating ? closed : 0,
                  child: child,
                );
              },
              child: frame(LoomaCatBlink.closedAsset),
            ),
          ],
        ),
      ),
    );
  }
}
