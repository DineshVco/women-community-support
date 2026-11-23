import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import 'cat_avatar.dart';

/// Small things the cat does when something happens.
enum CatCue {
  /// She published a post.
  wave,

  /// She tapped "Me too", or a post was confirmed.
  nod,
}

/// The Looma cat, gently alive: every few seconds it blinks and bobs 2 px,
/// then rests; at night its eyes stay closed (sleepy). It waves when she
/// posts and nods on [CatCue.nod]. No sound. With Reduce motion nothing
/// moves (night eyes are simply closed).
///
/// Uses the existing drawn cat (CatAvatar) with its eyes switched, so it
/// can blink.
class LivingCat extends StatefulWidget {
  const LivingCat({
    super.key,
    this.size = 48,
    this.night = false,
    this.startWith,
    this.listen = true,
  });

  final double size;

  /// Late at night: sleepy (closed) eyes, no blinking.
  final bool night;

  /// Plays once as soon as it appears (the success moment's nod).
  final CatCue? startWith;

  /// Reacts to [cue] (the hero cat). Off for one-off cats.
  final bool listen;

  /// The cat with open eyes, so a blink shows.
  static const String look = 'cat_02';

  /// Something happened: the cats that listen react.
  static final ValueNotifier<(CatCue, int)?> cues = ValueNotifier(null);
  static int _cueCount = 0;

  static void cue(CatCue cue) => cues.value = (cue, ++_cueCount);

  /// Every this long: a blink and a bob, then rest.
  static const Duration cycle = Duration(milliseconds: 4500);
  static const Duration blinkLength = Duration(milliseconds: 150);
  static const Duration bobLength = Duration(milliseconds: 1600);
  static const Duration gestureLength = Duration(milliseconds: 900);

  /// How far the gentle bob goes.
  static const double bobHeight = 2;

  @override
  State<LivingCat> createState() => _LivingCatState();
}

class _LivingCatState extends State<LivingCat> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: LivingCat.bobLength,
  );
  late final AnimationController _gesture = AnimationController(
    vsync: this,
    duration: LivingCat.gestureLength,
  );
  CatCue? _playing;
  Timer? _cycle;
  Timer? _blinkEnd;
  bool _blinking = false;
  bool _started = false;

  bool get _still => AppMotion.reduced(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.listen) LivingCat.cues.addListener(_onCue);
    if (_still) return;
    _cycle = Timer.periodic(LivingCat.cycle, (_) => _tick());
    if (widget.startWith != null) _play(widget.startWith!);
  }

  void _tick() {
    if (!mounted || _still) return;
    _bob.forward(from: 0);
    if (widget.night) return; // sleepy: no blinking
    setState(() => _blinking = true);
    _blinkEnd?.cancel();
    _blinkEnd = Timer(LivingCat.blinkLength, () {
      if (mounted) setState(() => _blinking = false);
    });
  }

  void _onCue() {
    final cue = LivingCat.cues.value;
    if (cue != null && mounted && !_still) _play(cue.$1);
  }

  void _play(CatCue cue) {
    setState(() => _playing = cue);
    _gesture.forward(from: 0);
  }

  @override
  void dispose() {
    LivingCat.cues.removeListener(_onCue);
    _cycle?.cancel();
    _blinkEnd?.cancel();
    _bob.dispose();
    _gesture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eyes = widget.night || _blinking ? CatEyes.closed : CatEyes.open;
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _gesture]),
      builder: (context, child) {
        // Bob: up 2 px and back down.
        final bob = -LivingCat.bobHeight * math.sin(math.pi * _bob.value);
        final g = _gesture.value;
        final fade = 1 - g; // the gesture settles
        var angle = 0.0;
        var dip = 0.0;
        if (_gesture.isAnimating || (g > 0 && g < 1)) {
          switch (_playing) {
            case CatCue.wave:
              // A small side-to-side wave, three times.
              angle = 0.16 * math.sin(3 * 2 * math.pi * g) * fade;
            case CatCue.nod:
              // Two small nods.
              dip = 3 * math.sin(2 * 2 * math.pi * g).abs() * fade;
            case null:
              break;
          }
        }
        return Transform.translate(
          offset: Offset(0, bob + dip),
          child: Transform.rotate(
            key: const ValueKey('living-cat-pose'),
            angle: angle,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: CatAvatar(
        key: const ValueKey('living-cat'),
        id: LivingCat.look,
        size: widget.size,
        eyes: eyes,
      ),
    );
  }
}

/// A tiny cat that pops up, nods once and fades (about a second) each time
/// [trigger] goes up: next to "Me too". Nothing with Reduce motion.
class CatNodFlash extends StatefulWidget {
  const CatNodFlash({super.key, required this.trigger, this.size = 22});

  /// Increase it to play the nod.
  final int trigger;
  final double size;

  static const Duration length = Duration(milliseconds: 1100);

  @override
  State<CatNodFlash> createState() => _CatNodFlashState();
}

class _CatNodFlashState extends State<CatNodFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CatNodFlash.length,
  );

  @override
  void didUpdateWidget(CatNodFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger > oldWidget.trigger && !AppMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (t == 0 || t == 1) return SizedBox.square(dimension: widget.size);
          // In quickly, two small nods, out softly.
          final opacity = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
          final dip = 2.5 * math.sin(2 * 2 * math.pi * t).abs() * (1 - t);
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, dip),
              child: CatAvatar(
                key: const ValueKey('nod-cat'),
                id: LivingCat.look,
                size: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }
}
