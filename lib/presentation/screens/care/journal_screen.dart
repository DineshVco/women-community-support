import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/journal.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/content_width.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/floating_illustration.dart';
import '../../widgets/ios.dart';
import '../../../core/theme/app_icons.dart';

/// My journal: private notes, only on this phone (encrypted). List, write,
/// edit, delete. Optional prompts to start from.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, this.store, this.prompts});

  /// For tests.
  final JournalStore? store;
  final List<String>? prompts;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final JournalStore _store = widget.store ?? context.read<JournalStore>();
  List<JournalEntry>? _entries;
  List<String> _prompts = JournalPrompts.fallback;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.prompts != null) {
      _prompts = widget.prompts!;
    } else {
      JournalPrompts.load().then((p) {
        if (mounted) setState(() => _prompts = p);
      });
    }
  }

  Future<void> _reload() async {
    try {
      final entries = await _store.load();
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _entries = const []);
    }
  }

  Future<void> _write() async {
    const blank = '\u0000blank';
    final choice = await showOptionsSheet<String>(
      context,
      title: 'New note',
      message: 'Start with a prompt, or a blank page.',
      options: [
        const SheetOption(value: blank, label: 'Blank page', isDefault: true),
        for (final p in _prompts) SheetOption(value: p, label: p),
      ],
    );
    if (choice == null || !mounted) return;
    await _open(prompt: choice == blank ? null : choice);
  }

  Future<void> _open({JournalEntry? entry, String? prompt}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => JournalEditor(store: _store, entry: entry, prompt: prompt),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = _entries;
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'My journal',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 44,
          onPressed: _write,
          child: Icon(
            AppIcons.journal,
            color: palette.text,
            semanticLabel: 'New note',
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child:
              entries == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : entries.isEmpty
                  ? ListView(
                    children: [
                      EmptyState(
                        illustration: LoomaCats.heart,
                        title: 'Your journal is empty',
                        message:
                            'Write whenever you like. Only you can read it, '
                            'and it stays on this phone.',
                        actionLabel: 'Write a note',
                        onAction: _write,
                      ),
                    ],
                  )
                  : ListView(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    children: [
                      GroupedSection(
                        footer: 'Only on this phone, encrypted.',
                        children: [
                          for (final e in entries)
                            GroupedRow(
                              title: e.title,
                              subtitle: localizations.formatMediumDate(
                                e.updatedAt,
                              ),
                              onTap: () => _open(entry: e),
                            ),
                        ],
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

/// Write or edit one note. Saved when she taps Done or goes back.
class JournalEditor extends StatefulWidget {
  const JournalEditor({
    super.key,
    required this.store,
    this.entry,
    this.prompt,
  });

  final JournalStore store;
  final JournalEntry? entry;
  final String? prompt;

  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late final _text = TextEditingController(text: widget.entry?.text ?? '');
  bool _saved = false;

  String? get _prompt => widget.entry?.prompt ?? widget.prompt;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Saves once. Empty new notes are not kept.
  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final text = _text.text.trim();
    final entry = widget.entry;
    if (entry == null) {
      if (text.isNotEmpty) await widget.store.add(text, prompt: _prompt);
    } else if (text != entry.text) {
      if (text.isEmpty) {
        await widget.store.delete(entry.id);
      } else {
        await widget.store.update(entry.id, text);
      }
    }
  }

  Future<void> _done() async {
    AppHaptics.light();
    await _save();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this note?',
      message: 'It will be gone from this phone. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    _saved = true;
    await widget.store.delete(entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      // Going back also saves.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        appBar: loomaNavBar(
          context,
          title: widget.entry == null ? 'New note' : 'Note',
          trailing: NavBarActions(
            children: [
              if (widget.entry != null)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minSize: 44,
                  onPressed: _delete,
                  child: Icon(
                    AppIcons.delete,
                    color: CupertinoColors.destructiveRed.resolveFrom(context),
                    semanticLabel: 'Delete note',
                  ),
                ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minSize: 44,
                onPressed: _done,
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_prompt != null) ...[
                    Text(
                      _prompt!,
                      style: TextStyle(
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Expanded(
                    child: CupertinoTextField(
                      controller: _text,
                      autofocus: widget.entry == null,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      placeholder: 'Write anything. Only you can read this.',
                      padding: EdgeInsets.zero,
                      decoration: null,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
