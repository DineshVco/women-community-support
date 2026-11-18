import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/content_filter.dart';
import '../../data/models/category.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/content_width.dart';
import 'help_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxTitle = 120;
  static const int _maxContent = 5000;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _categoryId;
  String? _error;
  bool _isPosting = false;

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
      final proceed = await _showSupportSheet();
      if (proceed != true || !mounted) return;
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Posted as $alias.')),
      );
    } on FirebaseException {
      _fail('Could not post. If you posted a moment ago, wait a minute and '
          'try again.');
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
  Future<bool?> _showSupportSheet() {
    final theme = Theme.of(context);

    return showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you okay?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'What you wrote sounds heavy. You can still post it, but '
                'talking to someone right now may help. The people on these '
                'lines are there to listen.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop(false);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HelpScreen(showBackButton: true),
                      ),
                    );
                  },
                  child: const Text('See who I can call'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Post anyway'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
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
                        onSelected: _isPosting
                            ? null
                            : (_) => setState(() => _categoryId = category.id),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isPosting ? null : _publish,
                    child: _isPosting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: palette.textMuted,
                            ),
                          )
                        : const Text('Post'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
