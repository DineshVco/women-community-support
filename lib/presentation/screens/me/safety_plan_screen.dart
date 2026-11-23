import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/safety_plan.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/app_lock_gate.dart';
import '../../widgets/content_width.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/quick_exit_button.dart';
import '../../widgets/ios.dart';
import 'app_lock_settings_screen.dart';
import '../../../core/theme/app_icons.dart';

/// Opens the safety plan. With App lock on, she types her PIN (or uses her
/// fingerprint / face) first, every time.
Future<void> openSafetyPlan(BuildContext context) async {
  final lock = AppLockScope.maybeOf(context);
  if (lock != null && lock.enabled) {
    final ok = await confirmWithPin(context, lock);
    if (!ok || !context.mounted) return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SafetyPlanScreen()));
}

/// Her private safety plan, saved only on this phone (encrypted).
class SafetyPlanScreen extends StatefulWidget {
  const SafetyPlanScreen({super.key, this.store});

  /// For tests. Defaults to the one provided above the app.
  final SafetyPlanStore? store;

  static const String onlyOnPhone =
      'Your plan is saved only on this phone, encrypted. It is never sent to '
      'Looma or any server, and it is not included in phone backups. If you '
      'lose or reset this phone, the plan is lost too.';

  static const String footer =
      'This is not an emergency service. In danger, call 999.';

  @override
  State<SafetyPlanScreen> createState() => _SafetyPlanScreenState();
}

class _SafetyPlanScreenState extends State<SafetyPlanScreen> {
  late final SafetyPlanStore _store =
      widget.store ?? context.read<SafetyPlanStore>();

  final _place = TextEditingController();
  final _codeWord = TextEditingController();
  final _notes = TextEditingController();
  List<SafeContact> _contacts = [];
  Set<String> _ready = {};

  bool _loading = true;
  bool _loadFailed = false;
  bool _dirty = false;
  String _status = '';
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _load();
    for (final c in [_place, _codeWord, _notes]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty && !_loadFailed) _store.save(_current());
    for (final c in [_place, _codeWord, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final plan = await _store.load();
      if (!mounted) return;
      _place.text = plan.safePlace;
      _codeWord.text = plan.codeWord;
      _notes.text = plan.notes;
      setState(() {
        _contacts = [...plan.contacts];
        _ready = {...plan.ready};
        _loading = false;
        _dirty = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  SafetyPlan _current() => SafetyPlan(
    contacts: _contacts,
    safePlace: _place.text.trim(),
    codeWord: _codeWord.text.trim(),
    ready: _ready,
    notes: _notes.text.trim(),
  );

  /// Saves a moment after she stops typing.
  void _changed() {
    if (_loading) return;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
    if (_status.isNotEmpty) setState(() => _status = '');
  }

  Future<void> _save() async {
    try {
      await _store.save(_current());
      _dirty = false;
      if (mounted) setState(() => _status = 'Saved on this phone');
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not save. Try again.');
    }
  }

  Future<void> _editContact([int? index]) async {
    final result = await showDialog<SafeContact>(
      context: context,
      builder:
          (_) =>
              _ContactDialog(initial: index == null ? null : _contacts[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _contacts = [..._contacts, result];
      } else {
        _contacts = [..._contacts]..[index] = result;
      }
    });
    _changed();
  }

  void _removeContact(int index) {
    AppHaptics.light();
    setState(() => _contacts = [..._contacts]..removeAt(index));
    _changed();
  }

  Future<void> _clear() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear your plan?',
      message:
          'This deletes everything in your safety plan from this phone. It '
          'cannot be undone.',
      confirmLabel: 'Clear my plan',
      destructive: true,
    );
    if (!confirmed) return;
    _saveTimer?.cancel();
    await _store.clear();
    if (!mounted) return;
    // Emptying the fields counts as typing: stop that from saving an
    // empty plan straight back.
    _loading = true;
    _place.text = '';
    _codeWord.text = '';
    _notes.text = '';
    _loading = false;
    _saveTimer?.cancel();
    setState(() {
      _contacts = [];
      _ready = {};
      _dirty = false;
      _loadFailed = false;
      _status = 'Your plan was cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final lock = AppLockScope.maybeOf(context);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(text, style: AppTypography.heading(22, palette.text)),
    );

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'Safety plan',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.xxl,
                    ),
                    children: [
                      _OnlyOnPhoneCard(
                        showLockTip: lock != null && !lock.enabled,
                      ),
                      if (_loadFailed) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Your saved plan could not be opened on this '
                          'phone. You can clear it and start again.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.danger,
                          ),
                        ),
                      ],

                      heading('Safe contacts'),
                      for (var i = 0; i < _contacts.length; i++)
                        _ContactRow(
                          contact: _contacts[i],
                          onEdit: () => _editContact(i),
                          onRemove: () => _removeContact(i),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _loadFailed ? null : _editContact,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.text,
                          ),
                          icon: const Icon(AppIcons.personAdd),
                          label: const Text('Add a contact'),
                        ),
                      ),

                      heading('A safe place I can go'),
                      TextField(
                        controller: _place,
                        enabled: !_loadFailed,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'For example: my sister\'s house',
                        ),
                      ),

                      heading('A code word to tell a friend'),
                      TextField(
                        controller: _codeWord,
                        enabled: !_loadFailed,
                        decoration: const InputDecoration(
                          hintText: 'A word that means "I need help, come now"',
                        ),
                      ),

                      heading('Things to keep ready'),
                      for (final (id, label) in SafetyPlan.readyItems)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(label),
                          value: _ready.contains(id),
                          onChanged:
                              _loadFailed
                                  ? null
                                  : (on) {
                                    AppHaptics.selection();
                                    setState(() {
                                      _ready =
                                          on == true
                                              ? {..._ready, id}
                                              : ({..._ready}..remove(id));
                                    });
                                    _changed();
                                  },
                        ),

                      heading('Notes'),
                      TextField(
                        controller: _notes,
                        enabled: !_loadFailed,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText: 'Anything else you want to remember',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _status,
                        key: const ValueKey('plan-status'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LoomaButton.outline(
                        label: 'Clear my plan',
                        onPressed: _clear,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        SafetyPlanScreen.footer,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
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

class _OnlyOnPhoneCard extends StatelessWidget {
  const _OnlyOnPhoneCard({required this.showLockTip});

  final bool showLockTip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Row(
            children: [
              Icon(AppIcons.mobile, color: palette.text),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Only on this phone',
                  style: AppTypography.heading(20, palette.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(SafetyPlanScreen.onlyOnPhone, style: theme.textTheme.bodyMedium),
          if (showLockTip) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tip: turn on App lock so nobody else can open your plan.',
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AppLockSettingsScreen(),
                    ),
                  ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: palette.text,
              ),
              child: const Text('Turn on App lock'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onEdit,
    required this.onRemove,
  });

  final SafeContact contact;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: palette.softFill,
        foregroundColor: palette.text,
        child: const Icon(AppIcons.person),
      ),
      title: Text(contact.name),
      subtitle: Text(
        contact.anytime
            ? '${contact.number} · can call anytime'
            : contact.number,
        style: theme.textTheme.bodySmall,
      ),
      onTap: onEdit,
      trailing: IconButton(
        tooltip: 'Remove ${contact.name}',
        icon: const Icon(AppIcons.close),
        onPressed: onRemove,
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.initial});

  final SafeContact? initial;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _number = TextEditingController(text: widget.initial?.number);
  late bool _anytime = widget.initial?.anytime ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _done() {
    if (_name.text.trim().isEmpty || _number.text.trim().isEmpty) {
      setState(() => _error = 'Add a name and a number.');
      return;
    }
    Navigator.of(context).pop(
      SafeContact(
        name: _name.text.trim(),
        number: _number.text.trim(),
        anytime: _anytime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add a contact' : 'Edit contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _number,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                errorText: _error,
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can be called anytime'),
              value: _anytime,
              onChanged: (v) => setState(() => _anytime = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _done, child: const Text('Save')),
      ],
    );
  }
}
