import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pictures in assets/images/hero/ for the right side of some cards.
class CardPictures {
  CardPictures._();

  /// Right side of the profile card on Me.
  static const String magnolia = 'assets/images/hero/hero_magnolia.webp';

  /// Right side of the "Today for you" card on Care.
  static const String catGrass = 'assets/images/hero/hero_cat_grass.webp';

  static final Map<String, Future<bool>> _exists = {};

  /// Whether [asset] is bundled with the app (asked once, then remembered).
  static Future<bool> exists(String asset) =>
      _exists.putIfAbsent(asset, () async {
        try {
          final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
          return manifest.listAssets().contains(asset);
        } catch (_) {
          return false;
        }
      });
}

/// A picture for the right side of a card. Its left [clearUntil] share is
/// fully clear, then it fades in until [fullFrom], so text can run into the
/// clear part but never sits on the picture. If the file is missing or cannot load, a soft gradient in
/// [fallback] colours shows instead. In dark mode it is dimmed.
class CardPicture extends StatelessWidget {
  const CardPicture({
    super.key,
    required this.asset,
    required this.fallback,
    this.alignment = Alignment.centerRight,
  });

  /// The picture is fully clear up to here (share of its own width)...
  static const double clearUntil = 0.4;

  /// ...and fully shown from here.
  static const double fullFrom = 0.8;

  final String asset;
  final List<Color> fallback;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradient = DecoratedBox(
      key: const ValueKey('card-picture-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fallback,
        ),
      ),
    );
    return ExcludeSemantics(
      child: Opacity(
        opacity: dark ? 0.55 : 1,
        child: ShaderMask(
          // Clear on the left, full on the right.
          shaderCallback:
              (rect) => const LinearGradient(
                colors: [Color(0x00000000), Color(0xFF000000)],
                stops: [clearUntil, fullFrom],
              ).createShader(rect),
          blendMode: BlendMode.dstIn,
          // Only tries to draw the picture once it is known to be in the
          // app (a missing file never reaches the image decoder).
          child: FutureBuilder<bool>(
            future: CardPictures.exists(asset),
            builder:
                (context, snap) =>
                    snap.data == true
                        ? Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          alignment: alignment,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => gradient,
                        )
                        : gradient,
          ),
        ),
      ),
    );
  }
}
