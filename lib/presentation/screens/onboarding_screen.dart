import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/haptics.dart';
import '../widgets/quick_exit_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/content_width.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/floating_illustration.dart';
import '../widgets/looma_button.dart';
import '../widgets/looma_character.dart';
import '../../core/theme/app_icons.dart';

/// First screen: four swipeable pages (Looma polish step 4).
///  1. The welcome page (wordmark, character, welcome line, four features).
///  2–4. A Looma cat drawing plus one idea each, as a big title and one line.
///       The drawing floats, and slides and fades a little with the swipe.
/// "Get Started" and "I already have an account" stay at the bottom on every
/// page. "Skip" (pages 2–4) jumps to the last page.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
    this.viewOnly = false,
  });

  /// "View introduction" from Me: one "Done" button instead of the sign-up
  /// buttons ([onGetStarted] is called).
  final bool viewOnly;

  /// "Get Started" → sign up.
  final VoidCallback onGetStarted;

  /// "I already have an account" → sign in.
  final VoidCallback onSignIn;

  static const int pageCount = 4;

  /// The page background: soft blush at the top to cream at the bottom.
  static const List<Color> lightBackground = [
    Color(0xFFF9E4DF),
    Color(0xFFFEF7F2),
  ];

  /// Dark mode, still warm: a deep rose-brown to near black.
  static const List<Color> darkBackground = [
    Color(0xFF2B201E),
    Color(0xFF141110),
  ];

  /// The faint painted blob behind each cat.
  static const Color lightBlob = Color(0xFFF1C4BC);
  static const Color darkBlob = Color(0xFF6E4842);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _ideas = [
    (
      asset: LoomaCats.share,
      label: 'Painting of a cat holding a heart-shaped letter',
      title: 'Share without your name',
      line:
          'A random alias, never your name. Other members can’t see who '
          'you are.',
    ),
    (
      asset: LoomaCats.browse,
      label: 'Painting of a cat at a round window with flowers',
      title: 'Browse by category',
      line:
          'Find stories on health, school, work and safety, and see you are '
          'not the only one.',
    ),
    (
      asset: LoomaCats.safe,
      label: 'Painting of a cat asleep by a lantern',
      title: 'Report what feels wrong',
      line: 'Moderators review reports to keep Looma kind.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _skip() {
    final last = OnboardingScreen.pageCount - 1;
    if (AppMotion.reduced(context)) {
      _pages.jumpToPage(last);
    } else {
      _pages.animateToPage(
        last,
        duration: AppMotion.slow,
        curve: AppMotion.enter,
      );
    }
  }

  /// "Skip" on pages 2–4; on page 1 its space is kept so nothing jumps.
  Widget _skipButton(BuildContext context) => AnimatedOpacity(
    opacity: _index == 0 ? 0 : 1,
    duration: AppMotion.of(context, AppMotion.fast),
    child: IgnorePointer(
      ignoring: _index == 0,
      child: ExcludeSemantics(
        excluding: _index == 0,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: TextButton(
            onPressed: _skip,
            style: TextButton.styleFrom(
              foregroundColor: context.palette.textSecondary,
            ),
            child: const Text('Skip'),
          ),
        ),
      ),
    ),
  );

  /// About how wide "Skip" is (its text, padding and gap).
  double _skipWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Skip',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width + 24 + AppSpacing.xs;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    // The dots and buttons fade in after the welcome page's own entrance.
    final buttonDelay = Entrance.firstItemDelay + Entrance.gap * 7;

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        key: const ValueKey('onboarding-background'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                dark
                    ? OnboardingScreen.darkBackground
                    : OnboardingScreen.lightBackground,
          ),
        ),
        child: SafeArea(
          child: ContentWidth(
            maxWidth: 520,
            child: Column(
              children: [
                // Quick exit on every page, top right; "Skip" beside it on
                // pages 2–4. The space is kept on page 1 so nothing jumps.
                SizedBox(
                  height: 48,
                  child: LayoutBuilder(
                    builder:
                        (context, box) => Row(
                          children: [
                            const Spacer(),
                            _skipButton(context),
                            QuickExitButton(
                              // The label goes if Skip and the pill would
                              // not both fit (small phone, large text).
                              iconOnly:
                                  QuickExitButton.widthFor(
                                        MediaQuery.textScalerOf(context),
                                      ) +
                                      _skipWidth(context) +
                                      AppSpacing.screenHorizontal * 2 >
                                  box.maxWidth,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (value) {
                      AppHaptics.selection();
                      setState(() => _index = value);
                    },
                    children: [
                      const _WelcomePage(),
                      for (var i = 0; i < _ideas.length; i++)
                        _IdeaPage(
                          pages: _pages,
                          index: i + 1,
                          current: _index == i + 1,
                          asset: _ideas[i].asset,
                          label: _ideas[i].label,
                          title: _ideas[i].title,
                          line: _ideas[i].line,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      FadeSlideIn(
                        delay: buttonDelay,
                        distance: 0,
                        child: _PageDots(
                          count: OnboardingScreen.pageCount,
                          index: _index,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FadeSlideIn(
                        delay: buttonDelay + Entrance.gap,
                        distance: 0,
                        child: LoomaButton.primary(
                          label: widget.viewOnly ? 'Done' : 'Get Started',
                          onPressed: widget.onGetStarted,
                        ),
                      ),
                      if (!widget.viewOnly) ...[
                        const SizedBox(height: AppSpacing.md),
                        FadeSlideIn(
                          delay: buttonDelay + Entrance.gap * 2,
                          distance: 0,
                          child: LoomaButton.outline(
                            label: 'I already have an account',
                            onPressed: widget.onSignIn,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Page 1: welcome ─────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  static const _features = [
    (
      icon: AppIcons.chat,
      title: 'Share Without Your Name',
      text:
          'A random alias, never your name. Other members can’t see who you are.',
    ),
    (
      icon: AppIcons.guides,
      title: 'Browse by Category',
      text: 'Explore discussions on topics that matter to you',
    ),
    (
      icon: AppIcons.people,
      title: 'Be Part of a Community',
      text: 'Connect with women who understand',
    ),
    (
      icon: AppIcons.safety,
      title: 'Report What Feels Wrong',
      text: 'Moderators review reports to keep Looma kind.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    const entrance = Entrance();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Column(
        children: [
          ...entrance.items([
            const Wordmark(size: AppTypography.wordmarkLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SUPPORT · SHARE · EMPOWER',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 13,
                letterSpacing: 1.8,
                color: palette.textSecondary,
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          entrance.character(const LoomaCharacter(height: 220)),
          const SizedBox(height: AppSpacing.lg),
          ...entrance.items([
            Column(
              children: [
                Text(
                  'Welcome to Looma',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge,
                ),
                HandDrawnUnderline(width: 170, color: palette.text),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A women community support app',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'a safer, brighter tomorrow',
              textAlign: TextAlign.center,
              style: AppTypography.script(24, palette.text),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _FeatureRow(features: _features),
          ]),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ───────────────────────── Pages 2–4: one idea each ─────────────────────────

class _IdeaPage extends StatelessWidget {
  const _IdeaPage({
    required this.pages,
    required this.index,
    required this.current,
    required this.asset,
    required this.label,
    required this.title,
    required this.line,
  });

  final PageController pages;
  final int index;
  final bool current;
  final String asset;
  final String label;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, page) {
        final box = IdeaArt.boxFor(
          page.biggest,
          textScale: MediaQuery.textScalerOf(context).scale(1),
        );
        final art = IdeaArt.fit(LoomaCats.aspect[asset] ?? 1, box);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              _Parallax(
                pages: pages,
                index: index,
                child: SizedBox(
                  key: ValueKey('idea-art-$index'),
                  width: box.width,
                  height: box.height,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // A faint painted blob behind the cat.
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: _BlobPainter(
                              seed: index,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? OnboardingScreen.darkBlob
                                      : OnboardingScreen.lightBlob,
                            ),
                          ),
                        ),
                      ),
                      FloatingIllustration(
                        asset: asset,
                        width: art.width,
                        height: art.height,
                        visible: current,
                        semanticLabel: label,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.heading(32, palette.text),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Sizes for the idea pages' pictures.
class IdeaArt {
  IdeaArt._();

  static const double maxWidth = 320;
  static const double maxHeight = 320;
  static const double minHeight = 110;

  /// The box is at most this much wider than tall, so a tall cat and a
  /// wide cat can both be the same size in it.
  static const double maxBoxAspect = 1.2;

  /// The same box on every idea page: about half the page height (less
  /// with large text, so the title and line keep their room), never wider
  /// than the page.
  static Size boxFor(Size page, {double textScale = 1}) {
    var height = page.height * (textScale > 1.4 ? 0.34 : 0.5);
    height = height.clamp(minHeight, maxHeight);
    final width = math.min(
      math.min(maxWidth, height * maxBoxAspect),
      math.max(0.0, page.width - 2 * AppSpacing.screenHorizontal),
    );
    return Size(width, height);
  }

  /// How much of the box each picture covers: as much as possible while
  /// the tallest and the widest cat still fit whole.
  static double weightFor(Size box) {
    final shapes = LoomaCats.aspect.values;
    final tallest = shapes.reduce(math.min);
    final widest = shapes.reduce(math.max);
    final ratio = box.width / box.height;
    return math.min(
      0.5,
      math.min(0.97 * tallest / ratio, 0.97 * ratio / widest),
    );
  }

  /// The picture's size inside [box]: the same area for every shape, and
  /// never bigger than the box (so it is never cropped).
  static Size fit(double aspect, Size box) {
    final area = box.width * box.height * weightFor(box);
    var w = math.sqrt(area * aspect);
    var h = w / aspect;
    final shrink = math.min(1.0, math.min(box.width / w, box.height / h));
    w *= shrink;
    h *= shrink;
    return Size(w, h);
  }
}

/// A soft, uneven, watercolour-like blob (two faint layers), different on
/// each page.
class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.seed, required this.color});

  final int seed;
  final Color color;

  Path _blob(Size size, int salt, double scale) {
    final random = math.Random(seed * 31 + salt);
    const points = 8;
    final c = size.center(Offset.zero);
    final rx = size.width / 2 * scale;
    final ry = size.height / 2 * scale;
    final pts = <Offset>[
      for (var i = 0; i < points; i++)
        () {
          final a = i * 2 * math.pi / points + random.nextDouble() * 0.3;
          final r = 0.82 + random.nextDouble() * 0.18;
          return c + Offset(math.cos(a) * rx * r, math.sin(a) * ry * r);
        }(),
    ];
    // A smooth closed curve through the points (Catmull-Rom).
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < points; i++) {
      final p0 = pts[(i - 1 + points) % points];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % points];
      final p3 = pts[(i + 2) % points];
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final (salt, scale, alpha) in [(1, 0.98, 0.42), (2, 0.8, 0.32)]) {
      final paint =
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: alpha * 0.35),
              ],
            ).createShader(rect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(_blob(size, salt, scale), paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.seed != seed || old.color != color;
}

// ───────────────────────── Pieces ─────────────────────────

/// Moves the picture of page [index] up to 24 px against the swipe and fades
/// it, so it lags a little behind its page and cross-fades with the next one.
/// Off with reduce motion (the page then just slides).
class _Parallax extends StatelessWidget {
  const _Parallax({
    required this.pages,
    required this.index,
    required this.child,
  });

  final PageController pages;
  final int index;
  final Widget child;

  static const double maxShift = 24;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;

    return AnimatedBuilder(
      animation: pages,
      child: child,
      builder: (context, child) {
        final page =
            pages.hasClients && pages.position.haveDimensions
                ? pages.page ?? index.toDouble()
                : index.toDouble();
        // 0 when this page is centred, ±1 when it is one page away.
        final offset = (index - page).clamp(-1.0, 1.0);
        return Opacity(
          opacity: 1 - offset.abs(),
          child: Transform.translate(
            offset: Offset(offset * maxShift, 0),
            child: child,
          ),
        );
      },
    );
  }
}

typedef _Feature = ({IconData icon, String title, String text});

/// Four features side by side, separated by thin vertical lines.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.features});

  final List<_Feature> features;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final children = <Widget>[];

    for (var i = 0; i < features.length; i++) {
      if (i > 0) {
        children.add(
          VerticalDivider(width: 1, thickness: 1, color: palette.border),
        );
      }
      children.add(Expanded(child: _FeatureTile(feature: features[i])));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.softFill,
              shape: BoxShape.circle,
            ),
            child: Icon(feature.icon, size: 24, color: palette.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: AppTypography.heading(
              12,
              palette.text,
              weight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            feature.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots; the active one grows into a longer pill.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.of(context, AppMotion.medium);

    return Semantics(
      label: 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.spring,
              width: i == index ? 22 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == index ? palette.blush : palette.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
