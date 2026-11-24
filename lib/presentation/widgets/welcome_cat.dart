import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'fade_slide_in.dart';

/// The tall, elegant line-drawn cat on the sign-in screen: a large, quiet
/// picture above the form, shown only when there is room. It is hidden
/// while the keyboard is open, with large text, and on short screens, so
/// the form is never pushed down. It fades in once (not with Reduce
/// motion). The lines are dark on the light theme and a soft cream on the
/// dark theme (one transparent picture, coloured in the app).
class WelcomeCat extends StatelessWidget {
  const WelcomeCat({super.key, this.animate = true, this.keyboard = 0});

  /// False after the screen's first frame: no fade when it comes back.
  final bool animate;

  /// The keyboard's height. Read by the screen above its Scaffold (inside
  /// the Scaffold body the keyboard is already taken out).
  final double keyboard;

  static const String asset = 'assets/images/hero/cat_elegant.webp';

  /// Width / height of the picture.
  static const double aspect = 314 / 900;

  /// As tall as this at most, and not shown if it would be shorter than
  /// [minHeight].
  static const double maxHeight = 200;
  static const double minHeight = 110;

  /// The form needs about this much height at normal text size.
  static const double formHeight = 640;

  /// Lines in dark mode: a soft cream.
  static const Color darkLine = Color(0xFFF2E6DA);

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
    final line = dark ? darkLine : context.palette.textSecondary;

    return GentleSize(
      alignment: Alignment.topCenter,
      child:
          height == 0
              ? const SizedBox(width: double.infinity)
              : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: ExcludeSemantics(
                    child: FadeSlideIn(
                      animate: animate,
                      distance: 0,
                      duration: Entrance.characterDuration,
                      child: SizedBox(
                        key: const ValueKey('welcome-cat'),
                        height: height,
                        width: height * aspect,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          color: line,
                          colorBlendMode: BlendMode.srcIn,
                          excludeFromSemantics: true,
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
