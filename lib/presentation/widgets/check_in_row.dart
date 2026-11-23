import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/haptics.dart';
import '../../data/encrypted_box.dart';
import '../../data/mood.dart';
import 'looma_card.dart';

/// What the check-in row offers next, after she picks a face.
enum CheckInStep { breathe, ground, journal }

/// "How are you today?" on Care: five soft faces. A tap saves today's entry
/// in the private mood log (the same encrypted store as "How are you
/// feeling", only on this phone), then shows one gentle line and one next
/// step. No scores, no streaks, no charts. Hidden on the web.
class CheckInRow extends StatefulWidget {
  const CheckInRow({super.key, this.store, this.today, required this.onStep});

  /// Defaults to the app's [MoodStore]; the row hides if there is none.
  final MoodStore? store;

  /// For tests.
  final DateTime? today;

  /// Opens the next step she chose.
  final ValueChanged<CheckInStep> onStep;

  static const String title = 'How are you today?';

  /// Left to right: hardest to best.
  static const List<Mood> order = [
    Mood.rough,
    Mood.low,
    Mood.okay,
    Mood.good,
    Mood.great,
  ];

  static IconData iconFor(Mood mood) => switch (mood) {
    Mood.rough => AppIcons.faceRough,
    Mood.low => AppIcons.faceLow,
    Mood.okay => AppIcons.faceOkay,
    Mood.good => AppIcons.faceGood,
    Mood.great => AppIcons.faceGreat,
  };

  /// One gentle line, never a judgement.
  static String replyFor(Mood mood) => switch (mood) {
    Mood.rough => 'Thank you for telling me. You do not have to fix it now.',
    Mood.low => 'That sounds heavy. Be gentle with yourself today.',
    Mood.okay => 'Okay is allowed. A small pause might help.',
    Mood.good => 'Good to hear. Notice what helped.',
    Mood.great => 'Lovely. Hold on to that feeling.',
  };

  /// One next step: calming first when it is hard.
  static (CheckInStep, String) stepFor(Mood mood) => switch (mood) {
    Mood.rough ||
    Mood.low => (CheckInStep.breathe, 'Breathe slowly with the cat'),
    Mood.okay => (CheckInStep.ground, 'Try a 1-minute reset'),
    Mood.good ||
    Mood.great => (CheckInStep.journal, 'Write down what went well'),
  };

  @override
  State<CheckInRow> createState() => _CheckInRowState();
}

class _CheckInRowState extends State<CheckInRow> {
  MoodStore? _store;
  MoodEntry? _todays;
  bool _loading = true;
  bool _changing = false;

  DateTime get _day {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store != null) return;
    _store = widget.store ?? _maybeStore();
    _load();
  }

  MoodStore? _maybeStore() {
    try {
      return context.read<MoodStore>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _load() async {
    final store = _store;
    if (store == null || !EncryptedBox.supported) return;
    try {
      final entries = await store.load();
      if (!mounted) return;
      setState(() {
        _todays = entries[MoodEntry.keyFor(_day)];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(Mood mood) async {
    final store = _store;
    if (store == null) return;
    // Mood saved: a light tap.
    AppHaptics.light();
    // Keeps a note she already wrote today on the mood screen.
    final entry = MoodEntry(day: _day, mood: mood, note: _todays?.note ?? '');
    setState(() {
      _todays = entry;
      _changing = false;
    });
    try {
      await store.save(entry);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null || !EncryptedBox.supported || _loading) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;
    final answered = _todays != null && !_changing;

    return LoomaCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    CheckInRow.title,
                    style: AppTypography.heading(20, palette.text),
                  ),
                ),
              ),
              if (answered)
                TextButton(
                  onPressed: () => setState(() => _changing = true),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.text,
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.medium),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            child:
                answered
                    ? _Answer(
                      key: ValueKey('answer-${_todays!.mood.name}'),
                      mood: _todays!.mood,
                      onStep: widget.onStep,
                    )
                    : _Faces(
                      key: const ValueKey('faces'),
                      selected: _todays?.mood,
                      onPick: _pick,
                    ),
          ),
        ],
      ),
    );
  }
}

class _Faces extends StatelessWidget {
  const _Faces({super.key, required this.selected, required this.onPick});

  final Mood? selected;
  final ValueChanged<Mood> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final mood in CheckInRow.order)
          Expanded(
            child: _Face(
              mood: mood,
              selected: mood == selected,
              onTap: () => onPick(mood),
            ),
          ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: mood.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FaceCircle(mood: mood, selected: selected),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  mood.label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 13, color: palette.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceCircle extends StatelessWidget {
  const _FaceCircle({required this.mood, this.selected = false});

  final Mood mood;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: mood.dot,
        shape: BoxShape.circle,
        border: Border.all(
          width: 2,
          color: selected ? palette.text : Colors.transparent,
        ),
      ),
      // Dark ink on the soft colour, in light and dark mode.
      child: Icon(
        CheckInRow.iconFor(mood),
        size: 26,
        color: const Color(0xFF111111),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({super.key, required this.mood, required this.onStep});

  final Mood mood;
  final ValueChanged<CheckInStep> onStep;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (step, label) = CheckInRow.stepFor(mood);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _FaceCircle(mood: mood),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today: ${mood.label}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CheckInRow.replyFor(mood),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // One next step, never a list of tasks.
        TextButton.icon(
          onPressed: () => onStep(step),
          iconAlignment: IconAlignment.end,
          style: TextButton.styleFrom(
            foregroundColor: palette.text,
            minimumSize: const Size(0, 44),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(AppIcons.chevronRight, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
