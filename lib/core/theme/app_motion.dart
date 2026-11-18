import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Animation timings. Everything stays between 150 and 300 ms so the app
/// feels responsive, never slow.
///
/// Always go through [AppMotion.of] so animations switch off when the person
/// has turned on "Remove animations" / "Reduce motion" on their phone.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);

  /// Gap between rows in a staggered entrance.
  static const Duration stagger = Duration(milliseconds: 40);

  /// For fades. Never use a spring on opacity: it overshoots past 1.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// iOS-style spring for movement and size: settles with a hint of
  /// overshoot (about 2%).
  static const Curve spring = SpringCurve();

  /// Bouncier spring for small "pop" feedback (about 12% overshoot).
  static const Curve springPop = SpringCurve(
    dampingRatio: 0.55,
    stiffness: 160,
  );

  /// True when the system asks apps to avoid animation.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when reduce-motion is on.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// A curve that follows a real damped spring (Flutter's own physics), so
/// motion starts quickly and settles naturally, like iOS animations.
///
/// The whole spring is fitted into the animation's duration. The stiffness
/// values used here make it fully settled by the end, so there is no jump.
class SpringCurve extends Curve {
  const SpringCurve({this.dampingRatio = 0.75, this.stiffness = 120});

  /// Below 1 overshoots; lower means bouncier.
  final double dampingRatio;

  /// Higher settles faster.
  final double stiffness;

  @override
  double transformInternal(double t) {
    final simulation = SpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: dampingRatio,
      ),
      0, // start
      1, // end
      0, // starting velocity
    );
    return simulation.x(t);
  }
}
