import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../providers/app_settings.dart';
import '../screens/auth_gate.dart';
import '../screens/decoy_screen.dart';
import 'app_lock_gate.dart';
import 'ios.dart';
import 'transient_overlays.dart';
import 'looma_button.dart';
import '../../core/theme/app_icons.dart';

/// Quick exit: one tap hides Looma behind an ordinary-looking screen
/// (weather or calculator, chosen in Settings).
///
/// Coming back: weather = press and hold anywhere for 1 second, or tap the
/// temperature 3 times (see DisguiseShell); calculator = type the
/// PIN and press "=" (or press and hold the numbers if no PIN is set).
/// With App lock on, Looma is locked as soon as it is hidden.
///
/// The very first tap (once per phone) shows a short explanation instead,
/// with "Got it" and "Try it". After that it is always a single tap with no
/// questions. No haptics on purpose: a buzz could draw attention.
class QuickExit {
  QuickExit._();

  /// Stored on the phone only.
  static const String introSeenKey = 'looma.quickExit.introSeen';

  /// Where a real Quick exit returns to: the top of the app. Tests swap it
  /// for a simple page (the real one needs Firebase).
  @visibleForTesting
  static WidgetBuilder home = (_) => const AuthGate();

  static const String introText =
      'Quick exit hides Looma. Press and hold to come back.';

  static Future<bool> introSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(introSeenKey) ?? false;
    } catch (_) {
      // If the flag cannot be read, never get in the way: just exit.
      return true;
    }
  }

  static Future<void> markIntroSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(introSeenKey, true);
    } catch (_) {}
  }

  /// What the Quick exit button does.
  static Future<void> onTap(BuildContext context) async {
    if (await introSeen()) {
      if (context.mounted) exitNow(context);
      return;
    }
    // Saved before the sheet opens, so it really shows only once.
    await markIntroSeen();
    if (!context.mounted) return;

    final tryIt = await showLoomaSheet<bool>(
      context,
      builder: (_) => const _IntroSheet(),
    );
    if (tryIt == true && context.mounted) exitNow(context);
  }

  static Widget _disguise(BuildContext context, {required bool practice}) {
    final screen =
        AppSettings.maybeOf(context)?.quickExitScreen ??
        QuickExitScreen.weather;
    return screen == QuickExitScreen.calculator
        ? CalculatorDisguise(practice: practice)
        : DecoyScreen(practice: practice);
  }

  /// Replaces the whole app with the disguise, instantly, and clears the
  /// back stack so "back" cannot reveal Looma.
  static void exitNow(BuildContext context) {
    _clearTransientUi(context);
    final lock = AppLockScope.maybeOf(context);
    lock?.disguiseActive = true;
    lock?.lockNow();
    final disguise = _disguise(context, practice: false);
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushAndRemoveUntil(instantRoute(disguise), (route) => false);
  }

  /// Opens the disguise on top of the current page with a small "practice"
  /// hint. Coming back returns to the same page (no lock).
  static Future<void> practice(BuildContext context) async {
    await markIntroSeen();
    if (!context.mounted) return;
    AppLockScope.maybeOf(context)?.disguiseActive = true;
    final disguise = _disguise(context, practice: true);
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(instantRoute(disguise));
  }

  /// Leaves the disguise. After a real Quick exit Looma restarts from the
  /// top; with App lock on, the lock screen shows first unless she has just
  /// typed her PIN into the calculator.
  static void comeBack(
    BuildContext context, {
    required bool practice,
    bool unlockedByPin = false,
  }) {
    _clearTransientUi(context);
    final lock = AppLockScope.maybeOf(context);
    lock?.disguiseActive = false;
    if (practice) {
      Navigator.of(context).pop();
      return;
    }
    if (!unlockedByPin) lock?.lockNow();
    Navigator.of(context).pushAndRemoveUntil(
      instantRoute(Builder(builder: home)),
      (route) => false,
    );
  }

  /// Nothing from Looma stays on screen across the switch: pop-ups drawn
  /// above every page, snackbars, and the keyboard. (Dialogs and sheets are
  /// routes, so they are cleared with the rest of the page stack.)
  static void _clearTransientUi(BuildContext context) {
    TransientOverlays.removeAll();
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// No slide or fade: the switch must be immediate.
  static PageRoute<void> instantRoute(Widget page) => PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => page,
  );
}

/// The compact pill in the header: eye-off icon and "Quick exit", 32 px
/// high, while the tap area stays at least 48 x 48 (Material pads it).
/// [iconOnly] drops the label when the header is too narrow (small phone,
/// large text); screen readers still hear "Quick exit".
class QuickExitButton extends StatelessWidget {
  const QuickExitButton({super.key, this.iconOnly = false});

  final bool iconOnly;

  /// The pill's visible height.
  static const double height = 32;

  /// The pill's natural width for [textScaler] (used by the header to
  /// decide whether the label fits).
  static double widthFor(TextScaler textScaler) {
    final label = TextPainter(
      text: const TextSpan(
        text: 'Quick exit',
        style: TextStyle(
          fontFamily: AppTypography.bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = 12 + 16 + 6 + label.width + 12;
    label.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextButton.styleFrom(
      foregroundColor: palette.text,
      backgroundColor: palette.surface.withValues(alpha: 0.7),
      minimumSize: Size(iconOnly ? height : 0, height),
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 12),
      shape: StadiumBorder(side: BorderSide(color: palette.border)),
      textStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontSize: 13, color: palette.text),
      // At least 48 x 48 to tap, however small the pill looks.
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    void onTap() => QuickExit.onTap(context);

    if (iconOnly) {
      return Semantics(
        button: true,
        label: 'Quick exit',
        excludeSemantics: true,
        child: TextButton(
          onPressed: onTap,
          style: style,
          child: const Icon(AppIcons.eyeSlash, size: 16),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      style: style,
      icon: const Icon(AppIcons.eyeSlash, size: 16),
      label: const Text('Quick exit', maxLines: 1),
    );
  }
}

class _IntroSheet extends StatelessWidget {
  const _IntroSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.eyeSlash, color: palette.text),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Quick exit',
                  style: AppTypography.heading(24, palette.text),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(QuickExit.introText, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            LoomaButton.primary(
              label: 'Try it',
              showArrow: false,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            LoomaButton.outline(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
