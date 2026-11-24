import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/membership.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_format.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/post_repository.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/choice_card.dart';
import '../../widgets/content_width.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/looma_character.dart';
import '../../widgets/quick_exit_button.dart';
import '../../../core/theme/app_icons.dart';

/// The two steps after creating a login, shown once per account:
///  1. Women only confirmation   2. Birthday (age check)
/// AuthGate shows this until `users/{uid}` has both answers.
class MembershipFlow extends StatefulWidget {
  const MembershipFlow({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<MembershipFlow> createState() => _MembershipFlowState();
}

class _MembershipFlowState extends State<MembershipFlow> {
  /// True when the person tapped back from the birthday step.
  bool _revisitStepOne = false;

  @override
  Widget build(BuildContext context) {
    final onStepOne = !widget.profile.isWoman || _revisitStepOne;

    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.medium),
      child:
          onStepOne
              ? _WomenOnlyStep(
                key: const ValueKey('step1'),
                alreadyConfirmed: widget.profile.isWoman,
                onConfirmed: () => setState(() => _revisitStepOne = false),
              )
              : _BirthdayStep(
                key: const ValueKey('step2'),
                onBack: () => setState(() => _revisitStepOne = true),
              ),
    );
  }
}

// ───────────────────────── Shared layout ─────────────────────────

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.step,
    required this.onBack,
    required this.title,
    required this.message,
    required this.children,
    required this.button,
    required this.entrance,
  });

  final Entrance entrance;

  /// 1 or 2 (out of 3; the third is the app itself).
  final int step;
  final VoidCallback? onBack;
  final String title;
  final String message;
  final List<Widget> children;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 480,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: LayoutBuilder(
                  builder:
                      (context, box) => Row(
                        children: [
                          IconButton(
                            onPressed: onBack,
                            tooltip: 'Back',
                            icon: const Icon(AppIcons.back, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Semantics(
                              label: 'Step $step of 3',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(end: step / 3),
                                  duration: AppMotion.of(
                                    context,
                                    AppMotion.slow,
                                  ),
                                  curve: AppMotion.enter,
                                  builder:
                                      (context, value, _) =>
                                          LinearProgressIndicator(
                                            value: value,
                                            minHeight: 3,
                                            color: palette.primary,
                                            backgroundColor: palette.border,
                                          ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Works before she has finished joining too. The
                          // label goes when the bar would get too short.
                          QuickExitButton(
                            iconOnly:
                                QuickExitButton.widthFor(
                                      MediaQuery.textScalerOf(context),
                                    ) +
                                    48 +
                                    AppSpacing.sm * 2 +
                                    96 >
                                box.maxWidth,
                          ),
                        ],
                      ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      entrance.character(
                        const Center(child: LoomaCharacter(height: 190)),
                      ),
                      ...entrance.items([
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          title,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: 32,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          message,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ...children,
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                ),
                child: entrance.items([button]).single,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm "we can't set up an account" screen with one button. The button
/// deletes the just-created login and signs out.
class _CannotJoin extends StatefulWidget {
  const _CannotJoin({required this.message});

  final String message;

  @override
  State<_CannotJoin> createState() => _CannotJoinState();
}

class _CannotJoinState extends State<_CannotJoin>
    with EntranceOnce<_CannotJoin> {
  bool _leaving = false;

  Future<void> _leave() async {
    setState(() => _leaving = true);
    // AuthGate shows the sign-in screen once the account is gone.
    await context.read<PostRepository>().discardNewAccount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 480,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.topRight,
                  child: QuickExitButton(),
                ),
                const Spacer(),
                entrance.character(const LoomaCharacter(height: 170)),
                ...entrance.items([
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 17,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const Spacer(),
                  LoomaButton.outline(
                    label: 'Go back',
                    loading: _leaving,
                    onPressed: _leave,
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Step 1: women only ─────────────────────────

class _WomenOnlyStep extends StatefulWidget {
  const _WomenOnlyStep({
    super.key,
    required this.alreadyConfirmed,
    required this.onConfirmed,
  });

  final bool alreadyConfirmed;
  final VoidCallback onConfirmed;

  @override
  State<_WomenOnlyStep> createState() => _WomenOnlyStepState();
}

class _WomenOnlyStepState extends State<_WomenOnlyStep>
    with EntranceOnce<_WomenOnlyStep> {
  bool _isWoman = true; // "I am a woman" is pre-selected.
  bool _declined = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!_isWoman) {
      setState(() => _declined = true);
      return;
    }
    if (widget.alreadyConfirmed) {
      widget.onConfirmed();
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<PostRepository>().confirmWoman();
      widget.onConfirmed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Back from step 1 means "not now": sign out, keep the login.
  Future<void> _back() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Leave sign-up?',
      message: 'You can sign in again later and carry on from here.',
      confirmLabel: 'Leave',
    );
    if (leave && mounted) await context.read<PostRepository>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_declined) {
      return const _CannotJoin(
        message:
            'Looma is only for women, so we can’t set up an account for you. '
            'Thank you for understanding.',
      );
    }

    return _StepScaffold(
      entrance: entrance,
      step: 1,
      onBack: _saving ? null : _back,
      title: 'Looma is a space for women',
      message:
          'Please confirm to continue. Your answer is private. Other members '
          'and moderators never see it.',
      button: LoomaButton.primary(
        label: 'Continue',
        loading: _saving,
        onPressed: _continue,
      ),
      children: [
        ChoiceCard(
          label: 'I am a woman',
          selected: _isWoman,
          onTap: () => setState(() => _isWoman = true),
        ),
        const SizedBox(height: AppSpacing.md),
        ChoiceCard(
          label: 'I am not a woman',
          selected: !_isWoman,
          onTap: () => setState(() => _isWoman = false),
        ),
      ],
    );
  }
}

// ───────────────────────── Step 2: birthday ─────────────────────────

class _BirthdayStep extends StatefulWidget {
  const _BirthdayStep({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<_BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<_BirthdayStep>
    with EntranceOnce<_BirthdayStep> {
  DateTime? _birthday;
  bool _tooYoung = false;
  bool _saving = false;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  Future<void> _pickDate() async {
    final today = _today;
    final initial = _birthday ?? DateTime(today.year - 25, today.month, 1);

    final DateTime? picked;
    if (useCupertino(context)) {
      picked = await _pickCupertino(initial, today);
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: today,
        helpText: 'Your birthday',
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        initialDatePickerMode: DatePickerMode.year,
      );
    }
    if (picked != null && mounted) {
      setState(() => _birthday = DateUtils.dateOnly(picked!));
    }
  }

  Future<DateTime?> _pickCupertino(DateTime initial, DateTime today) {
    var chosen = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder:
          (popupContext) => Container(
            height: 300,
            color: context.palette.surface,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      onPressed: () => Navigator.of(popupContext).pop(chosen),
                      child: const Text('Done'),
                    ),
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial,
                      minimumDate: DateTime(1900),
                      maximumDate: today,
                      onDateTimeChanged: (value) => chosen = value,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _continue() async {
    final birthday = _birthday;
    if (birthday == null) return;

    if (!Membership.isOldEnough(birthday, _today)) {
      setState(() => _tooYoung = true);
      return;
    }

    setState(() => _saving = true);
    try {
      // Only the year is stored. AuthGate opens the app once it is saved.
      await context.read<PostRepository>().saveBirthYear(birthday.year);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    if (_tooYoung) {
      return const _CannotJoin(
        message:
            'Looma is for women aged ${Membership.minimumAge} and over, so '
            'we can’t set up an account for you yet. '
            'Thank you for understanding.',
      );
    }

    final birthday = _birthday;
    final age = birthday == null ? null : Membership.ageOn(birthday, _today);

    return _StepScaffold(
      entrance: entrance,
      step: 2,
      onBack: _saving ? null : widget.onBack,
      title: 'When’s your birthday?',
      message:
          'We only use this to check you are old enough to join. '
          'It is kept private.',
      button: LoomaButton.primary(
        label: 'Continue',
        loading: _saving,
        onPressed: birthday == null ? null : _continue,
      ),
      children: [
        Semantics(
          button: true,
          label:
              birthday == null
                  ? 'Choose your birthday'
                  : 'Birthday, ${formatLongDate(birthday)}. Tap to change.',
          excludeSemantics: true,
          child: InkWell(
            onTap: _saving ? null : _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Birthday',
                suffixIcon: Icon(AppIcons.calendar),
              ),
              isEmpty: birthday == null,
              child: Text(
                birthday == null ? '' : formatLongDate(birthday),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        if (age != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            age == 1 ? '1 year old' : '$age years old',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(AppIcons.lock, size: 16, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Only your birth year is saved. Other members never see it.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
