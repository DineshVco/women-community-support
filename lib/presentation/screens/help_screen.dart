import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/helplines.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/content_width.dart';
import '../widgets/press_scale.dart';
import '../widgets/quick_exit_button.dart';

/// Static page with real phone numbers. Works with no internet and no account.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  Future<void> _call(BuildContext context, Helpline line) async {
    final uri = Uri(scheme: 'tel', path: line.number.replaceAll(' ', ''));
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      // Devices without a phone (emulator, laptop): copy the number instead.
      await Clipboard.setData(ClipboardData(text: line.number));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${line.number} copied.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get help'),
        automaticallyImplyLeading: showBackButton,
        actions: const [QuickExitButton(), SizedBox(width: AppSpacing.sm)],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: palette.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In danger right now?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: palette.danger,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Helplines.emergency.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PressScale(
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.danger,
                            foregroundColor: palette.surface,
                          ),
                          onPressed: () => _call(context, Helplines.emergency),
                          child: Text('Call ${Helplines.emergency.number}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Talk to someone', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You do not have to be in an emergency to call.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final line in Helplines.support) ...[
                const Divider(),
                _HelplineRow(line: line, onCall: () => _call(context, line)),
              ],
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Worried someone can see your screen? Use Quick exit at the '
                'top of this page. It hides the app behind a weather screen. '
                'Press and hold anywhere to come back.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.line, required this.onCall});

  final Helpline line;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onCall,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(line.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              line.number,
              style: theme.textTheme.titleSmall?.copyWith(
                color: context.palette.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.call_outlined, color: context.palette.primary),
          ],
        ),
      ),
    );
  }
}
