import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/content_filter.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/category.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/adaptive.dart';
import '../widgets/content_width.dart';
import '../widgets/looma_button.dart';
import '../widgets/ios.dart';
import 'help_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.initialTitle});

  /// Pre-filled title, e.g. the question of the day.
  final String? initialTitle;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxTitle = 120;
  static const int _maxContent = 5000;

  late final TextEditingController _titleController;
  final _contentController = TextEditingController();
  String? _categoryId;
  String? _error;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String? _validate(String title, String content) {
    if (_categoryId == null) return 'Choose a category.';
    if (title.length < 3) return 'Give your post a title (at least 3 letters).';
    if (content.isEmpty) return 'Write something to share.';
    if (ContentFilter.isDisrespectful('$title $content')) {
      return 'Please keep it respectful. Remove any abusive words and try again.';
    }
    return null;
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    final problem = _validate(title, content);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    if (ContentFilter.suggestsDistress('$title $content')) {
      final choice = await _showSupportSheet();
      if (!mounted) return;
      if (choice == _SupportChoice.getHelp) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const HelpScreen(showBackButton: true),
          ),
        );
        return;
      }
      if (choice != _SupportChoice.postAnyway) return;
    }

    setState(() {
      _isPosting = true;
      _error = null;
    });

    try {
      final alias = await context.read<PostRepository>().createPost(
        categoryId: _categoryId!,
        title: title,
        content: content,
      );
      if (!mounted) return;
      AppHaptics.medium();
      // The feed shows the "Posted" confirmation.
      Navigator.of(context).pop(alias);
    } on FirebaseException {
      _fail(
        'Could not post. If you posted a moment ago, wait a minute and '
        'try again.',
      );
    } catch (_) {
      _fail('Could not post. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _error = message;
    });
  }

  /// Shown before posting when the text sounds like the writer is struggling.
  /// Cupertino action sheet on iPhone, Material sheet on Android.
  Future<_SupportChoice?> _showSupportSheet() {
    return showOptionsSheet<_SupportChoice>(
      context,
      title: 'Are you okay?',
      message:
          'What you wrote sounds heavy. You can still post it, but talking to '
          'someone right now may help. The people on these lines are there '
          'to listen.',
      options: const [
        SheetOption(
          value: _SupportChoice.getHelp,
          label: 'See who I can call',
          isDefault: true,
        ),
        SheetOption(value: _SupportChoice.postAnyway, label: 'Post anyway'),
      ],
      cancelLabel: 'Keep editing',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: loomaNavBar(context, title: 'New post'),
      body: SafeArea(
        child: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Your name is never shown. You get a random alias for '
                    'this discussion only.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Category', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final category in AppCategories.all)
                      ChoiceChip(
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        showCheckmark: false,
                        onSelected:
                            _isPosting
                                ? null
                                : (_) {
                                  AppHaptics.selection();
                                  setState(() => _categoryId = category.id);
                                },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _titleController,
                  enabled: !_isPosting,
                  maxLength: _maxTitle,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'What do you want to talk about?',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _contentController,
                  enabled: !_isPosting,
                  maxLength: _maxContent,
                  minLines: 6,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Your story or question',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.danger,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                LoomaButton.primary(
                  label: 'Post',
                  loading: _isPosting,
                  onPressed: _publish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SupportChoice { getHelp, postAnyway }
