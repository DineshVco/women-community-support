import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';

/// The Looma cats. [share], [browse] and [safe] are painted (transparent
/// WebP, about 800 px); [heart] is the line drawing (900 × 900 PNG).
class LoomaCats {
  LoomaCats._();

  /// A cat holding a heart-shaped letter (tall).
  static const String share = 'assets/images/hero/onboarding_share.webp';

  /// A cat at a round window with flowers (round).
  static const String browse = 'assets/images/hero/onboarding_browse.webp';

  /// A cat asleep by a lantern (wide).
  static const String safe = 'assets/images/hero/onboarding_safe.webp';

  static const String heart = 'assets/images/looma_cat_heart.png';

  /// Width / height of each picture.
  static const Map<String, double> aspect = {
    share: 381 / 800,
    browse: 800 / 785,
    safe: 800 / 530,
  };

  /// Paintings show on any background; line drawings need a light card in
  /// dark mode.
  static bool isPainted(String asset) => aspect.containsKey(asset);
}

/// A drawing that gently floats (6 px up and down, every 3.5 s), and fades
/// in while rising 12 px when it becomes [visible].
///
/// With "reduce motion" on it is a still picture, shown at once.
/// In dark mode it sits on a white rounded card (the lines are dark),
/// like the girl on the welcome page.
class FloatingIllustration extends StatefulWidget {
  const FloatingIllustration({
    super.key,
    required this.asset,
    this.height = 260,
    this.width,
    this.visible = true,
    this.semanticLabel,
  });

  final String asset;
  final double height;

  /// The box is [height] square unless a width is given. The picture is
  /// always shown whole inside it.
  final double? width;

  /// The entrance plays when this becomes true (e.g. its onboarding page
  /// is the current page). Until then the picture is hidden.
  final bool visible;

  /// Read by screen readers. Without it the picture is decorative.
  final String? semanticLabel;

  static const double floatDistance = 6;
  static const double riseDistance = 12;
  static const Duration floatPeriod = Duration(milliseconds: 3500);
  static const Duration enterDuration = Duration(milliseconds: 450);

  @override
  State<FloatingIllustration> createState() => _FloatingIllustrationState();
}

class _FloatingIllustrationState extends State<FloatingIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: FloatingIllustration.floatPeriod,
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: FloatingIllustration.enterDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FloatingIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (AppMotion.reduced(context)) {
      _float
        ..stop()
        ..value = 0;
      _enter
        ..stop()
        ..value = 1;
      return;
    }
    if (!_float.isAnimating) _float.repeat();
    if (widget.visible && _enter.isDismissed) _enter.forward();
  }

  @override
  void dispose() {
    _float.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = widget.width ?? h;
    // Decode at display size, not 800-900 px.
    final cacheWidth = (w * MediaQuery.devicePixelRatioOf(context)).round();

    Widget picture = Image.asset(
      widget.asset,
      width: w,
      height: h,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
    );

    // Dark mode: a line drawing's dark lines need a light card behind them
    // (paintings do not).
    if (Theme.of(context).brightness == Brightness.dark &&
        !LoomaCats.isPainted(widget.asset)) {
      picture = Container(
        padding: EdgeInsets.all(h * 0.05),
        decoration: BoxDecoration(
          color: AppPalette.illustrationCard,
          borderRadius: BorderRadius.circular(AppRadius.card + 8),
        ),
        child: picture,
      );
    }

    final label = widget.semanticLabel;
    picture = Semantics(
      image: label != null,
      label: label,
      excludeSemantics: true,
      child: RepaintBoundary(child: picture),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_float, _enter]),
      builder: (context, child) {
        final e = Curves.easeOutCubic.transform(_enter.value);
        // 0 → 1 → 0 over one period, eased like a sine wave.
        final t = _float.value;
        final wave = Curves.easeInOutSine.transform(
          t < 0.5 ? t * 2 : 2 - t * 2,
        );
        final dy =
            -wave * FloatingIllustration.floatDistance +
            (1 - e) * FloatingIllustration.riseDistance;
        return Opacity(
          opacity: e,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: picture,
    );
  }
}
