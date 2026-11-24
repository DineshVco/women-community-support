import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/breath_pattern.dart';
import '../../widgets/floating_illustration.dart';
import '../../widgets/ios.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/quick_exit_button.dart';

enum _Stage { choose, running, done }

/// Breathe: a full, calm screen. The cat grows and shrinks inside a soft
/// circle: in 4 s, hold 4 s (optional), out 6 s. 1, 3 or 5 minutes.
/// A soft haptic at each change. With reduce motion: a text counter
/// instead of the moving circle.
class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});

  static const String doneMessage =
      'Well done. You gave yourself a calm moment. Take it with you.';

  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen> {
  static const Duration _tick = Duration(milliseconds: 100);

  _Stage _stage = _Stage.choose;
  int _minutes = 1;
  bool _hold = true;
  Duration _elapsed = Duration.zero;
  BreathPhase? _lastPhase;
  Timer? _timer;

  BreathPattern get _pattern => BreathPattern(hold: _hold);

  Duration get _total =>
      _pattern.cycle * _pattern.breathsIn(Duration(minutes: _minutes));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.lightImpact();
    setState(() {
      _stage = _Stage.running;
      _elapsed = Duration.zero;
      _lastPhase = null;
    });
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      final next = _elapsed + _tick;
      if (next >= _total) {
        _finish();
        return;
      }
      final phase = _pattern.at(next).phase;
      if (phase != _lastPhase) {
        HapticFeedback.selectionClick(); // soft, at each change
        _lastPhase = phase;
      }
      setState(() => _elapsed = next);
    });
  }

  void _finish() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    setState(() => _stage = _Stage.done);
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _stage = _Stage.choose);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: loomaNavBar(
        context,
        title: 'Breathe',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.slow),
          child: switch (_stage) {
            _Stage.choose => _buildChoose(context),
            _Stage.running => _buildRunning(context),
            _Stage.done => _buildDone(context),
          },
        ),
      ),
    );
  }

  Widget _buildChoose(BuildContext context) {
    final palette = context.palette;
    return ListView(
      key: const ValueKey('choose'),
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Center(
          child: FloatingIllustration(asset: LoomaCats.heart, height: 140),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Breathe slowly with the cat. In for 4, out for 6. There is no '
          'right or wrong way.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, height: 1.4, color: palette.text),
        ),
        const SizedBox(height: AppSpacing.xl),
        LoomaSegmented<int>(
          value: _minutes,
          options: const {1: '1 minute', 3: '3 minutes', 5: '5 minutes'},
          onChanged: (v) => setState(() => _minutes = v),
        ),
        const SizedBox(height: AppSpacing.md),
        GroupedSection(
          children: [
            GroupedSwitchRow(
              title: 'Hold after breathing in',
              subtitle: '4 seconds',
              value: _hold,
              onChanged: (v) => setState(() => _hold = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LoomaButton.primary(
          label: 'Start',
          showArrow: false,
          onPressed: _start,
        ),
      ],
    );
  }

  Widget _buildRunning(BuildContext context) {
    final palette = context.palette;
    final moment = _pattern.at(_elapsed);
    final reduced = AppMotion.reduced(context);
    final remaining = _total - _elapsed;
    final minutesLeft = (remaining.inSeconds / 60).ceil();

    final Widget visual;
    if (reduced) {
      // No moving circle: a calm number instead.
      visual = Text(
        '${moment.secondsLeft}',
        key: const ValueKey('breath-counter'),
        style: AppTypography.heading(96, palette.text),
      );
    } else {
      final size = 120 + 140 * moment.scale;
      visual = SizedBox(
        width: 280,
        height: 280,
        child: Center(
          child: Container(
            key: const ValueKey('breath-circle'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: palette.blushTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              LoomaCats.heart,
              width: size * 0.62,
              height: size * 0.62,
              cacheWidth: 400,
            ),
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('running'),
      children: [
        const Spacer(),
        visual,
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          liveRegion: true,
          child: Text(
            moment.phase.label,
            key: const ValueKey('breath-phase'),
            style: AppTypography.heading(32, palette.text),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          minutesLeft <= 1
              ? 'Less than a minute left'
              : 'About $minutesLeft minutes left',
          style: TextStyle(fontSize: 15, color: palette.textSecondary),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: LoomaButton.outline(label: 'Stop', onPressed: _stop),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final palette = context.palette;
    return ListView(
      key: const ValueKey('done'),
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const Center(
          child: FloatingIllustration(asset: LoomaCats.heart, height: 140),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          BreatheScreen.doneMessage,
          textAlign: TextAlign.center,
          style: AppTypography.heading(24, palette.text),
        ),
        const SizedBox(height: AppSpacing.xl),
        LoomaButton.primary(
          label: 'Done',
          showArrow: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.md),
        LoomaButton.outline(label: 'Breathe again', onPressed: _start),
      ],
    );
  }
}
