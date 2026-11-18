import 'dart:math';

/// The Breathe tool's rhythm: breathe in 4 s, (optionally) hold 4 s,
/// breathe out 6 s, repeated.
enum BreathPhase {
  inhale('Breathe in'),
  hold('Hold'),
  exhale('Breathe out');

  const BreathPhase(this.label);
  final String label;
}

class BreathMoment {
  const BreathMoment({
    required this.phase,
    required this.secondsLeft,
    required this.scale,
    required this.cycle,
  });

  final BreathPhase phase;

  /// Whole seconds left in this phase (for the text counter).
  final int secondsLeft;

  /// Size of the circle and cat, 0 (small) to 1 (full).
  final double scale;

  /// Which breath this is (0 = the first).
  final int cycle;
}

class BreathPattern {
  const BreathPattern({this.hold = true});

  final bool hold;

  static const Duration inhale = Duration(seconds: 4);
  static const Duration holdFor = Duration(seconds: 4);
  static const Duration exhale = Duration(seconds: 6);

  Duration get cycle => inhale + (hold ? holdFor : Duration.zero) + exhale;

  /// Where she is at [elapsed] since starting.
  BreathMoment at(Duration elapsed) {
    final cycleMs = cycle.inMilliseconds;
    final count = elapsed.inMilliseconds ~/ cycleMs;
    var t = elapsed.inMilliseconds % cycleMs;

    int left(int phaseMs, int intoPhase) =>
        ((phaseMs - intoPhase) / 1000).ceil().clamp(1, phaseMs ~/ 1000);

    if (t < inhale.inMilliseconds) {
      final p = t / inhale.inMilliseconds;
      return BreathMoment(
        phase: BreathPhase.inhale,
        secondsLeft: left(inhale.inMilliseconds, t),
        scale: _ease(p),
        cycle: count,
      );
    }
    t -= inhale.inMilliseconds;
    if (hold) {
      if (t < holdFor.inMilliseconds) {
        return BreathMoment(
          phase: BreathPhase.hold,
          secondsLeft: left(holdFor.inMilliseconds, t),
          scale: 1,
          cycle: count,
        );
      }
      t -= holdFor.inMilliseconds;
    }
    final p = t / exhale.inMilliseconds;
    return BreathMoment(
      phase: BreathPhase.exhale,
      secondsLeft: left(exhale.inMilliseconds, t),
      scale: 1 - _ease(p),
      cycle: count,
    );
  }

  /// How many whole breaths fit in [length] (at least 1). The session ends
  /// after the last full breath out, never in the middle of one.
  int breathsIn(Duration length) {
    final n = length.inMilliseconds ~/ cycle.inMilliseconds;
    return n < 1 ? 1 : n;
  }

  /// Smooth in and out (sine ease).
  static double _ease(double p) => 0.5 - 0.5 * cos(p.clamp(0.0, 1.0) * pi);
}
