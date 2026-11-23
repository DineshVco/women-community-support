import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/haptics.dart';
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

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _ideas = [
    (
      asset: LoomaCats.share,
      label: 'Drawing of a cat with a speech bubble holding a heart',
      title: 'Share anonymously',
      line:
          'Speak freely in a safe and respectful space. You get a random '
          'alias, never your name.',
    ),
    (
      asset: LoomaCats.browse,
      label: 'Drawing of a cat sitting on a stack of books',
      title: 'Browse by category',
      line:
          'Find stories on health, school, work and safety, and see you are '
          'not the only one.',
    ),
    (
      asset: LoomaCats.safe,
      label: 'Drawing of a cat holding a shield with a tick',
      title: 'Stay safe and protected',
      line:
          'Report anything harmful. Moderators keep Looma kind and respectful.',
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

  @override
  Widget build(BuildContext context) {
    // The dots and buttons fade in after the welcome page's own entrance.
    final buttonDelay = Entrance.firstItemDelay + Entrance.gap * 7;

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: Column(
            children: [
              // "Skip" on pages 2–4. The space is kept on page 1 so nothing jumps.
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: _index == 0 ? 0 : 1,
                    duration: AppMotion.of(context, AppMotion.fast),
                    child: IgnorePointer(
                      ignoring: _index == 0,
                      child: ExcludeSemantics(
                        excluding: _index == 0,
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
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
    );
  }
}

// ───────────────────────── Page 1: welcome ─────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  static const _features = [
    (
      icon: AppIcons.chat,
      title: 'Share Anonymously',
      text: 'Speak freely in a safe and respectful space',
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
      title: 'Stay Safe & Protected',
      text: 'Report harmful content, moderators keep the community respectful',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          _Parallax(
            pages: pages,
            index: index,
            child: FloatingIllustration(
              asset: asset,
              height: 260,
              visible: current,
              semanticLabel: label,
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
  }
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
