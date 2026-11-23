import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/content_library.dart';
import '../../../data/help_lines.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/floating_illustration.dart';
import '../../widgets/ios.dart';
import '../../widgets/quick_exit_button.dart';
import '../../../core/theme/app_icons.dart';

/// Directory: organisations and help lines from content/directory.json
/// ONLY. Call, open the website, or copy. Hours only when checked, and a
/// "Last checked" line on every entry.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, this.library});

  /// For tests.
  final ContentLibrary? library;

  static const String intro =
      'Organisations that can help. Numbers and hours change: please check '
      'their official website too.';

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  Future<ContentLibrary>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ready = widget.library ?? ContentScope.maybeOf(context);
    _load ??= ready != null ? Future.value(ready) : ContentLibrary.load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'Directory',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: FutureBuilder<ContentLibrary>(
            future: _load,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(
                  illustration: LoomaCats.heart,
                  title: 'Could not open the directory',
                  message: 'Please try again in a moment.',
                );
              }
              final library = snapshot.data;
              if (library == null) {
                return const Center(child: CupertinoActivityIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xxl,
                ),
                children: [
                  Text(
                    DirectoryScreen.intro,
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final e in library.directory) ...[
                    _EntryCard(entry: e),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final DirectoryEntry entry;

  Future<void> _openWebsite(BuildContext context) async {
    AppHaptics.light();
    final site = entry.website!;
    final uri = Uri.tryParse(site.startsWith('http') ? site : 'https://$site');
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final checked = entry.lastChecked;
    final details = [
      if (entry.sms != null) 'SMS: ${entry.sms}',
      if (entry.whatsapp != null) 'WhatsApp: ${entry.whatsapp}',
      if (entry.language != null) 'Language: ${entry.language}',
      if (entry.shownHours != null) 'Hours: ${entry.shownHours}',
      if (entry.shownSource != null) 'Source: ${entry.shownSource}',
    ];
    final small = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      foregroundColor: WidgetStatePropertyAll(palette.text),
      visualDensity: VisualDensity.compact,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.helps,
            style: TextStyle(fontSize: 15, color: palette.textSecondary),
          ),
          if (entry.number != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              entry.number!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ],
          if (entry.website != null)
            Text(
              entry.website!,
              style: TextStyle(fontSize: 15, color: palette.text),
            ),
          for (final d in details)
            Text(
              d,
              style: TextStyle(fontSize: 14, color: palette.textSecondary),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (entry.number != null)
                OutlinedButton.icon(
                  style: small.copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(color: palette.text),
                    ),
                  ),
                  onPressed: () => ContactActions.call(context, entry.number!),
                  icon: const Icon(AppIcons.phone, size: 18),
                  label: Text('Call', semanticsLabel: 'Call ${entry.name}'),
                ),
              if (entry.canMessage)
                OutlinedButton.icon(
                  style: small.copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(color: palette.text),
                    ),
                  ),
                  onPressed: () => ContactActions.message(context, entry),
                  icon: const Icon(AppIcons.chat, size: 18),
                  label: Text(
                    'Message',
                    semanticsLabel: 'Message ${entry.name}',
                  ),
                ),
              if (entry.website != null)
                OutlinedButton.icon(
                  style: small.copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(color: palette.text),
                    ),
                  ),
                  onPressed: () => _openWebsite(context),
                  icon: const Icon(AppIcons.globe, size: 18),
                  label: const Text('Website'),
                ),
              if (entry.copyNumber != null)
                TextButton.icon(
                  style: small,
                  onPressed:
                      () => ContactActions.copy(context, entry.copyNumber!),
                  icon: const Icon(AppIcons.copy, size: 18),
                  label: Text(
                    'Copy',
                    semanticsLabel: 'Copy ${entry.name} number',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            checked == null
                ? 'Last checked: not yet confirmed'
                : 'Last checked: '
                    '${MaterialLocalizations.of(context).formatMediumDate(checked)}',
            style: TextStyle(fontSize: 13, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
