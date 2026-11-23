import 'package:flutter/material.dart';

import '../../../core/constants/connect.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/content_filter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/chat_profile.dart';
import '../../widgets/cat_avatar.dart';
import '../../widgets/content_width.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/ios.dart';
import '../../widgets/fade_slide_in.dart';

/// What the editor hands back when she taps Save.
class ChatProfileDraft {
  const ChatProfileDraft({
    required this.alias,
    required this.avatarId,
    required this.bio,
    required this.interests,
    required this.lookingFor,
  });

  final String alias;
  final String avatarId;
  final String bio;
  final List<String> interests;
  final List<String> lookingFor;
}

/// Set up or edit the chat profile: avatar, alias, bio, interests and
/// what she is looking for. Saving goes through [onSave], so the screen
/// itself never talks to Firestore (and is easy to test).
class ChatProfileEditor extends StatefulWidget {
  const ChatProfileEditor({
    super.key,
    this.initial,
    this.email,
    this.displayName,
    required this.onSave,
  });

  final ChatProfile? initial;

  /// Used only to stop her real name or email name being used as an alias.
  final String? email;
  final String? displayName;

  final Future<void> Function(ChatProfileDraft draft) onSave;

  @override
  State<ChatProfileEditor> createState() => _ChatProfileEditorState();
}

class _ChatProfileEditorState extends State<ChatProfileEditor> {
  late final TextEditingController _alias = TextEditingController(
    text: widget.initial?.alias ?? '',
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.initial?.bio ?? '',
  );
  late String _avatarId =
      CatAvatars.isValid(widget.initial?.avatarId ?? '')
          ? widget.initial!.avatarId
          : CatAvatars.fallback;
  late final List<String> _interests = [...?widget.initial?.interests];
  late final List<String> _lookingFor = [...?widget.initial?.lookingFor];

  String? _aliasError;
  String? _bioError;
  String? _saveError;
  bool _saving = false;

  @override
  void dispose() {
    _alias.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _toggle(List<String> list, String id, int max) {
    AppHaptics.selection();
    setState(() {
      if (list.contains(id)) {
        list.remove(id);
      } else if (list.length < max) {
        list.add(id);
      }
    });
  }

  Future<void> _save() async {
    final aliasError = ChatProfileChecks.alias(
      _alias.text,
      email: widget.email,
      displayName: widget.displayName,
    );
    final bioError = ChatProfileChecks.bio(_bio.text);
    setState(() {
      _aliasError = aliasError;
      _bioError = bioError;
      _saveError = null;
    });
    if (aliasError != null || bioError != null) {
      AppHaptics.warning();
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        ChatProfileDraft(
          alias: _alias.text.trim(),
          avatarId: _avatarId,
          bio: _bio.text.trim(),
          interests: List.of(_interests),
          lookingFor: List.of(_lookingFor),
        ),
      );
      if (!mounted) return;
      AppHaptics.medium();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Could not save. Check your connection and try again. Links '
            'and contact details are not allowed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text.toUpperCase(), style: theme.textTheme.labelSmall),
    );

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: widget.initial == null ? 'Set up chat profile' : 'Chat profile',
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                'This is how you appear in Connect. It is separate from your '
                'posts and replies: nobody can link the two.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              label('Avatar'),
              _AvatarGrid(
                selected: _avatarId,
                onSelected: (id) {
                  AppHaptics.selection();
                  setState(() => _avatarId = id);
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              label('Chat alias'),
              TextField(
                controller: _alias,
                maxLength: ConnectOptions.aliasMax,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'e.g. moonreader',
                  helperText: '3 to 20 characters. Not your real name.',
                  errorText: _aliasError,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              label('Bio'),
              TextField(
                controller: _bio,
                maxLength: ConnectOptions.bioMax,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'One line about you, like: first-year nursing student '
                      'who loves cats.',
                  errorText: _bioError,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              label('Interests (up to ${ConnectOptions.maxInterests})'),
              _ChipChoice(
                options: ConnectOptions.interests,
                selected: _interests,
                max: ConnectOptions.maxInterests,
                onTap:
                    (id) =>
                        _toggle(_interests, id, ConnectOptions.maxInterests),
              ),
              const SizedBox(height: AppSpacing.xl),

              label('Looking for (up to ${ConnectOptions.maxLookingFor})'),
              _ChipChoice(
                options: ConnectOptions.lookingFor,
                selected: _lookingFor,
                max: ConnectOptions.maxLookingFor,
                onTap:
                    (id) =>
                        _toggle(_lookingFor, id, ConnectOptions.maxLookingFor),
              ),
              const SizedBox(height: AppSpacing.xl),

              GentleSize(
                curve: AppMotion.spring,
                child:
                    _saveError == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            _saveError!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.danger,
                            ),
                          ),
                        ),
              ),
              LoomaButton.primary(
                label: 'Save',
                showArrow: false,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final id in CatAvatars.ids)
          Semantics(
            button: true,
            selected: id == selected,
            child: GestureDetector(
              onTap: () => onSelected(id),
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 2.5,
                    color: id == selected ? palette.text : Colors.transparent,
                  ),
                ),
                child: CatAvatar(id: id, size: 56),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChipChoice extends StatelessWidget {
  const _ChipChoice({
    required this.options,
    required this.selected,
    required this.max,
    required this.onTap,
  });

  final List<ConnectOption> options;
  final List<String> selected;
  final int max;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final full = selected.length >= max;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option.label),
            selected: selected.contains(option.id),
            // When the limit is reached, only selected chips stay tappable.
            onSelected:
                full && !selected.contains(option.id)
                    ? null
                    : (_) => onTap(option.id),
          ),
      ],
    );
  }
}
