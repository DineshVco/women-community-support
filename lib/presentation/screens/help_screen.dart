import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/helplines.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/haptics.dart';
import '../widgets/content_width.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/floating_illustration.dart';
import '../widgets/ios.dart';
import '../widgets/looma_button.dart';
import '../widgets/press_scale.dart';
import '../widgets/quick_exit_button.dart';

/// Get help: calm, static, and works with no internet and no account.
///
///  You are not alone (+ the safe cat)
///  In danger right now?  → Call 999
///  Helplines grouped by need, each with Call and Copy
///  Safe ways to reach out
///  Worried someone can see your screen? → Practice Quick exit
///
/// Sections fade in 60 ms apart (not with reduce motion). Every icon is the
/// outlined style.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  static const String headerLine =
      'Help is a call away. You do not have to be in an emergency to reach out.';

  static const List<(IconData, String)> safeTips = [
    (
      Icons.phone_android_outlined,
      'If someone checks your phone, call from a phone they cannot see, like '
          'a friend\'s.',
    ),
    (
      Icons.history_outlined,
      'If it is safer, delete the call from your call history afterwards.',
    ),
    (
      Icons.key_outlined,
      'Agree a code word with someone you trust, so you can ask for help '
          'without saying it out loud.',
    ),
  ];

  static Future<void> call(BuildContext context, Helpline line) async {
    AppHaptics.medium();
    final uri = Uri(scheme: 'tel', path: line.number.replaceAll(' ', ''));
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    // Devices without a phone (emulator, laptop): copy the number instead.
    if (!opened && context.mounted) await copy(context, line);
  }

  static Future<void> copy(BuildContext context, Helpline line) async {
    AppHaptics.light();
    await Clipboard.setData(ClipboardData(text: line.number));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied ${line.number}')));
  }

  @override
  Widget build(BuildContext context) {
    const entrance = Entrance();

    return LargeTitleScaffold(
      title: 'Get help',
      // Opened from "Write a post": a back chevron.
      leading: showBackButton ? const CupertinoNavigationBarBackButton() : null,
      trailing: const QuickExitButton(),
      slivers: [
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: entrance.items([
                  const _Header(),
                  const SizedBox(height: AppSpacing.xl),
                  const _EmergencyCard(),
                  const SizedBox(height: AppSpacing.xl),
                  for (final group in Helplines.groups) ...[
                    _GroupSection(group: group),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  const _SafeWaysCard(),
                  const SizedBox(height: AppSpacing.lg),
                  const _QuickExitCard(),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Sections ─────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are not alone',
                style: AppTypography.heading(28, palette.text, height: 1.1),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                HelpScreen.headerLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const FloatingIllustration(
          asset: LoomaCats.safe,
          height: 96,
          semanticLabel: 'Drawing of a cat holding a shield',
        ),
      ],
    );
  }
}

/// Soft blush-white card with a thin danger-coloured left edge.
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    const line = Helplines.emergency;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          color: palette.blushTint,
          border: Border(left: BorderSide(color: palette.danger, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg + 4,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_in_talk_outlined, color: palette.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'In danger right now?',
                    style: AppTypography.heading(22, palette.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(line.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            PressScale(
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: const StadiumBorder(),
                    // Body font (headings only use Newsreader).
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => HelpScreen.call(context, line),
                  icon: const Icon(Icons.call_outlined),
                  label: Text('Call ${line.number}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group});

  final HelplineGroup group;

  static const Map<String, IconData> _icons = {
    '03-7627 2929': Icons.chat_bubble_outline,
    '15999': Icons.support_agent_outlined,
    '03-3000 8858': Icons.shield_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final checked = group.lastChecked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.title, style: AppTypography.heading(22, palette.text)),
        const SizedBox(height: AppSpacing.sm),
        for (final line in group.lines) ...[
          _HelplineRow(
            line: line,
            icon: _icons[line.number] ?? Icons.call_outlined,
          ),
          if (line != group.lines.last) const Divider(height: 1),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          checked == null
              ? 'Last checked: not yet confirmed'
              : 'Last checked: '
                  '${MaterialLocalizations.of(context).formatMediumDate(checked)}',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.line, required this.icon});

  final Helpline line;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final dark = theme.brightness == Brightness.dark;

    final small = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      foregroundColor: WidgetStatePropertyAll(palette.text),
      visualDensity: VisualDensity.compact,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dark ? palette.softFill : const Color(0xFFF2F2F2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: palette.text),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  line.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  line.number,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      style: small.copyWith(
                        side: WidgetStatePropertyAll(
                          BorderSide(color: palette.text),
                        ),
                      ),
                      onPressed: () => HelpScreen.call(context, line),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: Text('Call', semanticsLabel: 'Call ${line.name}'),
                    ),
                    TextButton.icon(
                      style: small,
                      onPressed: () => HelpScreen.copy(context, line),
                      icon: const Icon(Icons.content_copy_outlined, size: 18),
                      label: Text(
                        'Copy',
                        semanticsLabel: 'Copy ${line.name} number',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeWaysCard extends StatelessWidget {
  const _SafeWaysCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safe ways to reach out',
            style: AppTypography.heading(22, palette.text),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (icon, tip) in HelpScreen.safeTips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: palette.text),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(tip, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickExitCard extends StatelessWidget {
  const _QuickExitCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_off_outlined, color: palette.text),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Worried someone can see your screen?',
                  style: AppTypography.heading(22, palette.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap Quick exit at the top of any page. Looma is replaced by a '
            'weather screen straight away. To come back, press and hold '
            'anywhere for 1 second, or tap the temperature 3 times.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          LoomaButton.outline(
            label: 'Practice Quick exit',
            onPressed: () => QuickExit.practice(context),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}
