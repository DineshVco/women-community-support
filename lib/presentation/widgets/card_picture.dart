import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pictures in assets/images/hero/ for the right side of some cards.
class CardPictures {
  CardPictures._();

  /// Right side of the profile card on Me.
  static const String magnolia = 'assets/images/hero/hero_magnolia.webp';

  /// The painted cat asleep on a pink cushion (cut-out): the "Today for
  /// you" card on Care, the late-night Discuss hero and empty lists.
  static const String catSleep = 'assets/images/hero/cat_sleep.webp';

  /// Its width / height.
  static const double catSleepAspect = 800 / 528;

  /// A pink yarn ball with a loose thread (cut-out): "no saved posts".
  static const String yarnFull = 'assets/images/hero/yarn_full.webp';
  static const double yarnFullAspect = 600 / 571;

  /// Answers already found (only finished answers are kept, never a lookup
  /// still in progress, so one slow lookup can never block later ones).
  static final Map<String, bool> _known = {};

  /// The answer if it is already known, else null.
  static bool? knownExists(String asset) => _known[asset];

  /// Whether [asset] is bundled with the app.
  static Future<bool> exists(String asset) async {
    final known = _known[asset];
    if (known != null) return known;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return _known[asset] = manifest.listAssets().contains(asset);
    } catch (_) {
      return false;
    }
  }
}

/// A picture for the right side of a card. Its left [clearUntil] share is
/// fully clear, then it fades in until [fullFrom], so text can run into the
/// clear part but never sits on the picture. If the file is missing or
/// cannot load, a soft gradient in [fallback] colours shows instead. In
/// dark mode it is dimmed.
class CardPicture extends StatefulWidget {
  const CardPicture({
    super.key,
    required this.asset,
    required this.fallback,
    this.alignment = Alignment.centerRight,
    this.fit = BoxFit.cover,
    this.scale = 1,
    this.clearUntil = defaultClearUntil,
    this.fullFrom = defaultFullFrom,
    this.darkOpacity = 0.55,
  });

  /// By default the picture is fully clear up to here (share of its own
  /// width)...
  static const double defaultClearUntil = 0.4;

  /// ...and fully shown from here.
  static const double defaultFullFrom = 0.8;

  final String asset;
  final List<Color> fallback;
  final Alignment alignment;
  final BoxFit fit;

  /// Draws the picture bigger, from [alignment] (e.g. 1.3 = 30% bigger).
  final double scale;

  /// The fade, as shares of the picture's width; 0 and 0 = no fade (a
  /// cut-out picture such as the napping cat).
  final double clearUntil;
  final double fullFrom;

  bool get fades => fullFrom > 0;

  /// In dark mode paintings are dimmed against glare; a cut-out picture
  /// (the napping cat) stays nearly full so it does not look grey.
  final double darkOpacity;

  @override
  State<CardPicture> createState() => _CardPictureState();
}

class _CardPictureState extends State<CardPicture> {
  /// Clear on the left, full on the right (unless the picture does not
  /// fade).
  Widget _fadeIn(Widget child) {
    if (!widget.fades) return child;
    return ShaderMask(
      shaderCallback:
          (rect) => LinearGradient(
            colors: const [Color(0x00000000), Color(0xFF000000)],
            stops: [widget.clearUntil, widget.fullFrom],
          ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  /// Asked once per card; known at once if another card already asked.
  late bool? _exists = CardPictures.knownExists(widget.asset);

  @override
  void initState() {
    super.initState();
    if (_exists == null) {
      CardPictures.exists(widget.asset).then((found) {
        if (mounted) setState(() => _exists = found);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradient = DecoratedBox(
      key: const ValueKey('card-picture-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.fallback,
        ),
      ),
    );
    return ExcludeSemantics(
      child: Opacity(
        opacity: dark ? widget.darkOpacity : 1,
        child: _fadeIn(
          _exists == true
              ? ClipRect(
                child: Transform.scale(
                  scale: widget.scale,
                  alignment: widget.alignment,
                  child: Image.asset(
                    widget.asset,
                    fit: widget.fit,
                    alignment: widget.alignment,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => gradient,
                  ),
                ),
              )
              : gradient,
        ),
      ),
    );
  }
}
