import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/mood.dart';
import '../../widgets/content_width.dart';
import '../../widgets/ios.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/mood_face.dart';
import '../help_screen.dart';
import '../../../core/theme/app_icons.dart';
import '../../widgets/quick_exit_button.dart';

/// How are you feeling: tap a cat face, add a line if you like, saved only
/// on this phone. A month calendar with small coloured dots and a gentle
/// weekly line. No scores, no streaks, no red.
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key, this.store, this.today});

  /// For tests. Defaults to the one provided above the app.
  final MoodStore? store;

  /// For tests.
  final DateTime? today;

  static const String helpCardTitle = 'Want to talk to someone?';

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  late final MoodStore _store = widget.store ?? context.read<MoodStore>();
  late final DateTime _today = _dayOf(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);

  final _note = TextEditingController();
  Map<String, MoodEntry> _entries = {};
  Mood? _selected;
  bool _loading = true;
  bool _saving = false;
  String _status = '';

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final entries = await _store.load();
      if (!mounted) return;
      final todays = entries[MoodEntry.keyFor(_today)];
      setState(() {
        _entries = entries;
        _selected = todays?.mood;
        _note.text = todays?.note ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final mood = _selected;
    if (mood == null) return;
    setState(() => _saving = true);
    try {
      final entries = await _store.save(
        MoodEntry(day: _today, mood: mood, note: _note.text.trim()),
      );
      AppHaptics.light();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _status = 'Saved on this phone.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Could not save. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = MoodCalendar.daysLoggedThisWeek(_entries, _today);

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'How are you feeling',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child:
              _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                      AppSpacing.screenHorizontal,
                      AppSpacing.xxl,
                    ),
                    children: [
                      Text(
                        'How are you feeling today?',
                        style: AppTypography.heading(26, palette.text),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final mood in Mood.values)
                            _FaceButton(
                              mood: mood,
                              selected: _selected == mood,
                              onTap: () {
                                AppHaptics.selection();
                                setState(() {
                                  _selected = mood;
                                  _status = '';
                                });
                              },
                            ),
                        ],
                      ),
                      if (_selected != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        CupertinoTextField(
                          controller: _note,
                          maxLength: 80,
                          placeholder: 'A few words, if you like (optional)',
                          padding: const EdgeInsets.all(14),
                          style: TextStyle(color: palette.text, fontSize: 16),
                          decoration: BoxDecoration(
                            color: palette.softFill,
                            borderRadius: BorderRadius.circular(
                              AppRadius.field,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LoomaButton.primary(
                          label: 'Save',
                          showArrow: false,
                          loading: _saving,
                          onPressed: _save,
                        ),
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        ],
                        if (_selected!.offerHelp) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const _HelpCard(),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        MoodCalendar.weeklyLine(days),
                        key: const ValueKey('weekly-line'),
                        style: TextStyle(fontSize: 15, color: palette.text),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MonthView(
                        month: _month,
                        today: _today,
                        entries: _entries,
                        onPrevious:
                            () => setState(
                              () =>
                                  _month = DateTime(
                                    _month.year,
                                    _month.month - 1,
                                  ),
                            ),
                        onNext:
                            _month.year == _today.year &&
                                    _month.month == _today.month
                                ? null
                                : () => setState(
                                  () =>
                                      _month = DateTime(
                                        _month.year,
                                        _month.month + 1,
                                      ),
                                ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Only on this phone. No scores and no streaks: just '
                        'a gentle look back.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 2.5,
                  color: selected ? palette.text : Colors.transparent,
                ),
              ),
              child: MoodFace(mood: mood, size: 54),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: palette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under a low or rough check-in: a soft offer, never pushy.
class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.blushTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MoodScreen.helpCardTitle,
            style: AppTypography.heading(20, palette.text),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You do not have to carry this alone. The help lines are free '
            'to call.',
            style: TextStyle(fontSize: 15, color: palette.text),
          ),
          const SizedBox(height: AppSpacing.md),
          LoomaButton.outline(
            label: 'See help lines',
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HelpScreen(showBackButton: true),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.today,
    required this.entries,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final DateTime today;
  final Map<String, MoodEntry> entries;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cells = MoodCalendar.monthGrid(month.year, month.month);
    final title = MaterialLocalizations.of(context).formatMonthYear(month);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 44,
                onPressed: onPrevious,
                child: Icon(
                  AppIcons.chevronLeft,
                  color: palette.text,
                  semanticLabel: 'Previous month',
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 44,
                onPressed: onNext,
                child: Icon(
                  AppIcons.chevronRight,
                  color: onNext == null ? palette.border : palette.text,
                  semanticLabel: 'Next month',
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var row = 0; row < cells.length ~/ 7; row++)
            Row(
              children: [
                for (final day in cells.skip(row * 7).take(7))
                  Expanded(
                    child: _DayCell(
                      day: day,
                      isToday:
                          day != null &&
                          MoodEntry.keyFor(day) == MoodEntry.keyFor(today),
                      entry:
                          day == null ? null : entries[MoodEntry.keyFor(day)],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isToday, this.entry});

  final DateTime? day;
  final bool isToday;
  final MoodEntry? entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = day;
    if (d == null) return const SizedBox(height: 44);
    return Semantics(
      label: entry == null ? '${d.day}' : '${d.day}, ${entry!.mood.label}',
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration:
                  isToday
                      ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.text),
                      )
                      : null,
              child: Text(
                '${d.day}',
                style: TextStyle(fontSize: 13, color: palette.text),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              key: entry == null ? null : ValueKey('dot-${d.day}'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry?.mood.dot ?? Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
