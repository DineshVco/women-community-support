import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/brand_mark.dart';
import '../widgets/content_width.dart';

/// Three short pages in plain words. No stock illustrations or icon circles.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_Page> _pages = [
    _Page(
      kicker: 'Anonymous',
      title: 'Say it without\nyour name.',
      body: 'You post and reply under a random alias, and it changes in every '
          'discussion. Other members and moderators never see who you are.',
    ),
    _Page(
      kicker: 'Community',
      title: 'Find people who\nhave been there.',
      body: 'Read and share about health, studies, work and staying safe. '
          'Tap “Me too” when someone puts your experience into words.',
    ),
    _Page(
      kicker: 'Safety',
      title: 'Looked after by\nreal people.',
      body: 'Report anything harmful. A moderator reviews it, and you can see '
          'what was decided. Help numbers are one tap away.',
    ),
  ];

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      widget.onGetStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Wordmark(),
                    if (!isLast)
                      TextButton(
                        onPressed: widget.onSignIn,
                        child: const Text('Skip'),
                      ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, i) {
                      final page = _pages[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${i + 1} of ${_pages.length}  ·  '
                            '${page.kicker.toUpperCase()}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.accent,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(page.title, style: theme.textTheme.headlineLarge),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            page.body,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      Container(
                        width: i == _index ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i == _index ? palette.primary : palette.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onSignIn,
                    child: const Text('I already have an account'),
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

class _Page {
  const _Page({
    required this.kicker,
    required this.title,
    required this.body,
  });

  final String kicker;
  final String title;
  final String body;
}
