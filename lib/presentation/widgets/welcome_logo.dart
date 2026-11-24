import 'package:flutter/material.dart';

import 'fade_slide_in.dart';

/// The Looma logo (the painted cat in its flower circle, with the name) on
/// the sign-in screen, shown only when there is room. It is hidden while the
/// keyboard is open, with large text, and on short screens, so the form is
/// never pushed down. It fades in once (not with Reduce motion). In dark
/// mode the brown lettering would be too dark, so a copy with soft cream
/// lettering is used.
class WelcomeLogo extends StatelessWidget {
  const WelcomeLogo({super.key, this.animate = true, this.keyboard = 0});

  /// False after the screen's first frame: no fade when it comes back.
  final bool animate;

  /// The keyboard's height. Read by the screen above its Scaffold (inside
  /// the Scaffold body the keyboard is already taken out).
  final double keyboard;

  static const String asset = 'assets/images/hero/looma_logo.webp';

  /// The same logo with cream lettering, for dark backgrounds.
  static const String darkAsset = 'assets/images/hero/looma_logo_dark.webp';

  /// Width / height of the logo.
  static const double aspect = 1000 / 1283;

  /// As tall as this at most, and not shown if it would be shorter than
  /// [minHeight] (the name would be too small to read).
  static const double maxHeight = 220;
  static const double minHeight = 120;

  /// The form needs about this much height at normal text size.
  static const double formHeight = 640;

  /// How tall to draw it, or 0 to hide it.
  static double heightFor({
    required double screenHeight,
    required double textScale,
    required double keyboard,
    double safeArea = 0,
  }) {
    if (keyboard > 0 || textScale > 1.3) return 0;
    final room = screenHeight - safeArea - formHeight * textScale;
    final h = room.clamp(0.0, maxHeight);
    return h < minHeight ? 0 : h;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = heightFor(
      screenHeight: mq.size.height,
      textScale: mq.textScaler.scale(1),
      keyboard: keyboard,
      safeArea: mq.padding.vertical,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GentleSize(
      alignment: Alignment.topCenter,
      child:
          height == 0
              ? const SizedBox(width: double.infinity)
              : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: Semantics(
                    image: true,
                    label: 'Looma',
                    excludeSemantics: true,
                    child: FadeSlideIn(
                      animate: animate,
                      distance: 0,
                      duration: Entrance.characterDuration,
                      child: SizedBox(
                        key: const ValueKey('welcome-logo'),
                        height: height,
                        width: height * aspect,
                        child: Image.asset(
                          dark ? darkAsset : asset,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          cacheWidth:
                              (height * aspect * mq.devicePixelRatio).round(),
                          // If it cannot load, simply nothing.
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
