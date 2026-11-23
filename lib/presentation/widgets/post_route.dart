import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Opening a post: it fades in and rises softly from where the card was,
/// while the feed stays still behind it. Closing plays it in reverse. The
/// iPhone edge swipe-back still works (the page then follows the finger).
/// With Reduce motion the post simply appears.
class PostRoute<T> extends MaterialPageRoute<T> {
  PostRoute({required super.builder, super.settings});

  /// How far it rises: 4% of the screen height (about 30 px).
  static const Offset rise = Offset(0, 0.04);

  @override
  Duration get transitionDuration => AppMotion.slow;

  @override
  Duration get reverseTransitionDuration => AppMotion.medium;

  /// The feed does not slide away underneath.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  CurvedAnimation? _curve;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final swiping = popGestureInProgress;
    // Keeps the edge swipe-back. Its slide only moves while swiping.
    final page = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      this,
      context,
      swiping ? animation : kAlwaysCompleteAnimation,
      secondaryAnimation,
      child,
    );
    if (swiping) return page;
    final curve =
        _curve ??= CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
    return FadeTransition(
      key: const ValueKey('post-route-fade'),
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: rise, end: Offset.zero).animate(curve),
        child: page,
      ),
    );
  }

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }
}
