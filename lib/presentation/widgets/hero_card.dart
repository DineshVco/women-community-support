import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import 'press_scale.dart';
import '../../core/theme/app_icons.dart';

/// The painted scenes in assets/images/hero/ (no people in them).
enum HeroScene {
  morning('assets/images/hero/hero_morning.webp'),
  dusk('assets/images/hero/hero_dusk.webp'),

  /// Late at night: a moon over lavender hills.
  night('assets/images/hero/hero_night.webp'),
  flowers('assets/images/hero/hero_flowers.webp');

  const HeroScene(this.asset);

  final String asset;

  /// Discuss: the morning painting by day (5:00–16:59), dusk in the evening
  /// (17:00–21:59), and the night sky from 22:00 until 5:00. Same bands as
  /// the greeting.
  static HeroScene forTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 17) return HeroScene.morning;
    if (hour >= 17 && hour < 22) return HeroScene.dusk;
    return HeroScene.night;
  }
}

/// The veil that keeps text readable: strongest on the left (under the
/// text), fading out to the right so the painting shows. Kept as numbers
/// so the tests can check AA contrast over the darkest and lightest pixels.
class HeroVeil {
  const HeroVeil({
    required this.textWidth,
    required this.stops,
    required this.lightAlphas,
    required this.darkAlphas,
    this.tinted = false,
  });

  /// Text stays inside this share of the card's width.
  final double textWidth;

  /// Where the veil's strength changes (0 = left edge, 1 = right edge),
  /// and how strong it is there, in light and dark mode.
  final List<double> stops;
  final List<double> lightAlphas;
  final List<double> darkAlphas;

  /// Discuss: a blush gradient instead of plain cream.
  final bool tinted;

  /// Text on the left 55%, the painting showing on the right.
  static const HeroVeil standard = HeroVeil(
    textWidth: 0.55,
    stops: [0, 0.45, 0.55, 0.75, 1],
    lightAlphas: [0.94, 0.88, 0.82, 0.15, 0.04],
    // Dark mode is dimmer on the right, so the painting does not glare.
    darkAlphas: [0.92, 0.86, 0.82, 0.30, 0.20],
  );

  /// Care: a wider text column (65%) so "A calm corner for you" fits on
  /// one line, and a lighter veil over the vase.
  static const HeroVeil care = HeroVeil(
    textWidth: 0.65,
    stops: [0, 0.55, 0.65, 0.8, 1],
    lightAlphas: [0.94, 0.88, 0.82, 0.10, 0],
    darkAlphas: [0.92, 0.86, 0.82, 0.25, 0.15],
  );

  /// Discuss (mockup): the blush tint #FAE7E0 to #F2CDC4, strong behind the
  /// text and clear from 60% to the right edge, so the painting shows on
  /// the right. Dark mode keeps a faint veil there against glare.
  static const HeroVeil discuss = HeroVeil(
    tinted: true,
    textWidth: 0.55,
    stops: [0, 0.45, 0.55, 0.6, 1],
    lightAlphas: [0.95, 0.9, 0.85, 0, 0],
    darkAlphas: [0.92, 0.88, 0.85, 0.2, 0.2],
  );

  static const List<HeroVeil> all = [standard, care, discuss];

  /// A soft blush wash in the top left corner (light mode).
  static const double blushWash = 0.18;

  /// The plain veil's colour: warm cream in light mode, near-black in dark.
  static Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF0E0E0E)
          : const Color(0xFFFEF7F2);

  /// The tint's colour at [x], between the two gradient colours.
  static Color tintColorAt(List<Color> gradient, double x) =>
      Color.lerp(gradient.first, gradient.last, x)!;

  List<double> alphasFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAlphas : lightAlphas;

  /// The veil's colour at [x].
  Color colorAt(Brightness brightness, List<Color> tint, double x) =>
      tinted ? tintColorAt(tint, x) : colorFor(brightness);

  /// The veil's strength at [x] (0 = left edge, 1 = right edge).
  double alphaAt(Brightness brightness, double x) {
    final alphas = alphasFor(brightness);
    for (var i = 1; i < stops.length; i++) {
      if (x <= stops[i]) {
        final t = (x - stops[i - 1]) / (stops[i] - stops[i - 1]);
        return alphas[i - 1] + (alphas[i] - alphas[i - 1]) * t;
      }
    }
    return alphas.last;
  }
}

/// A large rounded card with a painted scene, a soft veil, text on the
/// left and a gentle fade at the bottom edge. Tapping gives a light haptic.
/// If the painting cannot load, a soft gradient shows instead.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.scene,
    required this.children,
    this.actionLabel,
    this.onTap,
    this.minHeight = 176,
    this.paintingScale = 1,
    this.veil = HeroVeil.standard,
  });

  final HeroScene scene;

  /// Discuss uses a short hero (120) so posts show sooner.
  final double minHeight;

  /// Enlarges the painting from its right side (Care's flower vase).
  final double paintingScale;

  /// How the text side is veiled (see [HeroVeil] presets).
  final HeroVeil veil;

  /// The text, top to bottom, on the left of the card.
  final List<Widget> children;

  /// A small "… ›" line under the text when the card does something.
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(AppRadius.card);
    final alphas = veil.alphasFor(brightness);

    final text = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        // The padding takes a little of the card, so the text stays well
        // inside the strong part of the veil.
        widthFactor: veil.textWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...children,
            if (actionLabel != null && onTap != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(AppIcons.chevronRight, size: 14, color: palette.text),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final card = ClipRRect(
      borderRadius: radius,
      child: ConstrainedBox(
        // Full width; as tall as the text needs (large text grows it).
        constraints: BoxConstraints(
          minHeight: minHeight,
          minWidth: double.infinity,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.scale(
                key: const ValueKey('hero-painting'),
                scale: paintingScale,
                alignment: Alignment.centerRight,
                child: _Painting(scene: scene),
              ),
            ),
            // The veil: strong on the left, under the text.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    stops: veil.stops,
                    colors: [
                      for (var i = 0; i < veil.stops.length; i++)
                        veil
                            .colorAt(
                              brightness,
                              palette.discussHeroGradient,
                              veil.stops[i],
                            )
                            .withValues(alpha: alphas[i]),
                    ],
                  ),
                ),
              ),
            ),
            if (brightness == Brightness.light)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.center,
                      colors: [
                        palette.blush.withValues(alpha: HeroVeil.blushWash),
                        palette.blush.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            // A gentle fade into the page at the bottom edge.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.background.withValues(alpha: 0),
                      palette.background.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
            text,
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      AppHaptics.light();
                      onTap!();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      hint: onTap == null ? null : actionLabel,
      child:
          onTap == null
              ? card
              : PressScale(scale: PressScale.card, child: card),
    );
  }
}

/// The painting, decoded at the card's size (not the file's 2880 px), with
/// a soft fade-in once loaded (none with Reduce motion), and a gradient
/// while loading or if it fails.
class _Painting extends StatelessWidget {
  const _Painting({required this.scene});

  final HeroScene scene;

  @override
  Widget build(BuildContext context) {
    final fallback = HeroFallback(scene: scene);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite
                ? (constraints.maxWidth * ratio).round().clamp(1, 2880)
                : null;
        return Image.asset(
          scene.asset,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          cacheWidth: width,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => fallback,
          frameBuilder: (context, child, frame, sync) {
            if (sync) return child;
            return Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: AppMotion.of(context, AppMotion.slow),
                  curve: AppMotion.enter,
                  child: child,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The soft gradient shown while a painting loads, or if it cannot load.
class HeroFallback extends StatelessWidget {
  const HeroFallback({super.key, required this.scene});

  final HeroScene scene;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = switch ((scene, dark)) {
      (HeroScene.flowers, false) => const [
        Color(0xFFF6E4DF),
        Color(0xFFE3ECDD),
      ],
      (HeroScene.morning, false) => const [
        Color(0xFFFBF1E4),
        Color(0xFFF3D9D2),
      ],
      (_, false) => const [Color(0xFFF1DCD6), Color(0xFFD9CFE0)],
      (HeroScene.flowers, true) => const [Color(0xFF2A2324), Color(0xFF1F2620)],
      (_, true) => const [Color(0xFF2A2224), Color(0xFF1C1B24)],
    };
    return DecoratedBox(
      key: const ValueKey('hero-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}
