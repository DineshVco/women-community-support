import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../widgets/floating_illustration.dart';
import '../../widgets/ios.dart';
import '../../widgets/looma_button.dart';

/// Ground yourself: the 5-4-3-2-1 exercise, one step per screen, big text,
/// a Next button, and a kind message at the end.
class GroundScreen extends StatefulWidget {
  const GroundScreen({super.key});

  static const List<(int, String, String)> steps = [
    (5, 'Name 5 things you can see', 'Look around slowly. Big or small.'),
    (
      4,
      'Name 4 things you can feel',
      'Your feet on the floor, your clothes, the air.',
    ),
    (3, 'Name 3 things you can hear', 'Near or far. Even quiet sounds.'),
    (2, 'Name 2 things you can smell', 'Or two smells you like.'),
    (1, 'Name 1 thing you can taste', 'Or take a slow sip of water.'),
  ];

  static const String endMessage =
      'You are here, right now. Well done for taking this moment for '
      'yourself.';

  @override
  State<GroundScreen> createState() => _GroundScreenState();
}

class _GroundScreenState extends State<GroundScreen> {
  int _step = 0;

  bool get _finished => _step >= GroundScreen.steps.length;

  void _next() {
    AppHaptics.light();
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final Widget body;
    if (_finished) {
      body = Column(
        key: const ValueKey('ground-end'),
        children: [
          const Spacer(),
          const FloatingIllustration(asset: LoomaCats.heart, height: 140),
          const SizedBox(height: AppSpacing.xl),
          Text(
            GroundScreen.endMessage,
            textAlign: TextAlign.center,
            style: AppTypography.heading(26, palette.text),
          ),
          const Spacer(),
          LoomaButton.primary(
            label: 'Done',
            showArrow: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.md),
          LoomaButton.outline(
            label: 'Start again',
            onPressed: () => setState(() => _step = 0),
          ),
        ],
      );
    } else {
      final (number, title, hint) = GroundScreen.steps[_step];
      body = Column(
        key: ValueKey('ground-$_step'),
        children: [
          const Spacer(),
          Text(
            '$number',
            style: AppTypography.heading(96, palette.text, height: 1),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.heading(32, palette.text),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: palette.textSecondary),
          ),
          const Spacer(),
          _Dots(count: GroundScreen.steps.length, index: _step),
          const SizedBox(height: AppSpacing.lg),
          LoomaButton.primary(
            label: _step == GroundScreen.steps.length - 1 ? 'Finish' : 'Next',
            showArrow: false,
            onPressed: _next,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: loomaNavBar(context, title: 'Ground yourself'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.slow),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: i == index ? 22 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i <= index ? palette.text : palette.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
