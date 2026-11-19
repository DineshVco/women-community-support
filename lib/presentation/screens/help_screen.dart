import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/helplines.dart';
import '../../data/content_library.dart';
import '../../data/help_lines.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/contact_actions.dart';
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

  static Future<void> call(BuildContext context, Helpline line) =>
      ContactActions.call(context, line.number);

  static Future<void> copy(BuildContext context, Helpline line) =>
      ContactActions.copy(context, line.number);

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
                  const EmergencyCard(),
                  const SizedBox(height: AppSpacing.xl),
                  const HelpLineGroupsView(),
                  const SafeWaysCard(),
                  const SizedBox(height: AppSpacing.lg),
                  const QuickExitCard(),
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
class EmergencyCard extends StatelessWidget {
  const EmergencyCard({super.key});

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

/// All help line groups from content/directory.json, each followed by a
/// gap. Used by Get help and the Care tab, so both always match the file.
class HelpLineGroupsView extends StatelessWidget {
  const HelpLineGroupsView({super.key});

  @override
  Widget build(BuildContext context) {
    return WithContent(
      builder: (context, library) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in HelpLines.groupsFrom(library)) ...[
              HelplineGroupSection(group: group),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        );
      },
    );
  }
}

class HelplineGroupSection extends StatelessWidget {
  const HelplineGroupSection({super.key, required this.group});

  final HelpLineGroup group;

  static const Map<String, IconData> _icons = {
    'befrienders-kl': Icons.chat_bubble_outline,
    'talian-kasih': Icons.support_agent_outlined,
    'wao-hotline': Icons.shield_outlined,
    'wao-tina': Icons.sms_outlined,
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
        for (final entry in group.entries) ...[
          _HelplineRow(
            entry: entry,
            icon:
                _icons[entry.id] ??
                (entry.number == null
                    ? Icons.sms_outlined
                    : Icons.call_outlined),
          ),
          if (entry != group.entries.last) const Divider(height: 1),
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
  const _HelplineRow({required this.entry, required this.icon});

  final DirectoryEntry entry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final dark = theme.brightness == Brightness.dark;
    final number = entry.number;
    final messageNumber = entry.whatsapp ?? entry.sms;
    final copyNumber = entry.copyNumber;

    final small = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      foregroundColor: WidgetStatePropertyAll(palette.text),
      visualDensity: VisualDensity.compact,
    );
    final outlined = small.copyWith(
      side: WidgetStatePropertyAll(BorderSide(color: palette.text)),
    );
    final numberStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
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
                Text(entry.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  entry.helps,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (number != null) Text(number, style: numberStyle),
                if (number == null && messageNumber != null)
                  Text(messageNumber, style: numberStyle),
                if (entry.shownHours != null)
                  Text(
                    'Hours: ${entry.shownHours}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (number != null)
                      OutlinedButton.icon(
                        style: outlined,
                        onPressed: () => ContactActions.call(context, number),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: Text(
                          'Call',
                          semanticsLabel: 'Call ${entry.name}',
                        ),
                      ),
                    if (entry.canMessage)
                      OutlinedButton.icon(
                        style: outlined,
                        onPressed: () => ContactActions.message(context, entry),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: Text(
                          'Message',
                          semanticsLabel: 'Message ${entry.name}',
                        ),
                      ),
                    if (copyNumber != null)
                      TextButton.icon(
                        style: small,
                        onPressed:
                            () => ContactActions.copy(context, copyNumber),
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                        label: Text(
                          'Copy',
                          semanticsLabel: 'Copy ${entry.name} number',
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

class SafeWaysCard extends StatelessWidget {
  const SafeWaysCard({super.key});

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

class QuickExitCard extends StatelessWidget {
  const QuickExitCard({super.key});

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
