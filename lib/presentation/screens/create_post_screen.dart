import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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
  const CreatePostScreen({
    super.key,
    this.initialTitle,
    this.initialCategoryId,
    this.startAsPoll = false,
  });

  /// Pre-filled title, e.g. the question of the day.
  final String? initialTitle;

  /// Pre-chosen category, e.g. "Ask Looma Team".
  final String? initialCategoryId;
  final bool startAsPoll;

  static const String pollNote =
      'Polls are anonymous too. Nobody can see who voted or what anyone '
      'chose. Everyone can vote once, and sees the results after voting.';

  static const String askNote =
      'Your question is posted in Discuss under a random alias. The Looma '
      'team will answer as "Looma Team".';

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _maxTitle = 120;
  static const int _maxContent = 5000;
  static const int _maxOption = 60;

  late final TextEditingController _titleController;
  final _contentController = TextEditingController();
  late String? _categoryId = widget.initialCategoryId;
  String? _error;
  bool _isPosting = false;

  /// A poll instead of a normal post.
  late bool _isPoll = widget.startAsPoll;
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _optionTexts => [
    for (final c in _options)
      if (c.text.trim().isNotEmpty) c.text.trim(),
  ];

  String? _validate(String title, String content) {
    if (_categoryId == null) return 'Choose a category.';
    if (title.length < 3) {
      return _isPoll
          ? 'Write your question (at least 3 letters).'
          : 'Give your post a title (at least 3 letters).';
    }
    if (_isPoll) {
      final options = _optionTexts;
      if (options.length < 2) return 'Add at least 2 answers.';
      if (options.toSet().length != options.length) {
        return 'Each answer must be different.';
      }
    } else if (content.isEmpty) {
      return 'Write something to share.';
    }
    final all = [title, content, if (_isPoll) ..._optionTexts].join(' ');
    if (ContentFilter.isDisrespectful(all)) {
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
        pollOptions: _isPoll ? _optionTexts : null,
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

  /// 2 to 4 answer fields, with Add and remove.
  List<Widget> _buildOptions(ThemeData theme) {
    return [
      Text('Answers (2 to 4)', style: theme.textTheme.labelLarge),
      const SizedBox(height: AppSpacing.sm),
      for (var i = 0; i < _options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('poll-option-$i'),
                  controller: _options[i],
                  enabled: !_isPosting,
                  maxLength: _maxOption,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Answer ${i + 1}',
                    counterText: '',
                  ),
                ),
              ),
              if (_options.length > 2)
                IconButton(
                  tooltip: 'Remove answer ${i + 1}',
                  onPressed:
                      _isPosting
                          ? null
                          : () =>
                              setState(() => _options.removeAt(i).dispose()),
                  icon: const Icon(CupertinoIcons.minus_circle),
                ),
            ],
          ),
        ),
      if (_options.length < 4)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                _isPosting
                    ? null
                    : () =>
                        setState(() => _options.add(TextEditingController())),
            icon: const Icon(CupertinoIcons.add_circled, size: 18),
            label: const Text('Add an answer'),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: loomaNavBar(context, title: _isPoll ? 'New poll' : 'New post'),
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
                    _categoryId == AppCategories.askLoomaId
                        ? CreatePostScreen.askNote
                        : _isPoll
                        ? CreatePostScreen.pollNote
                        : 'Your name is never shown. You get a random alias '
                            'for this discussion only.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LoomaSegmented<bool>(
                  value: _isPoll,
                  options: const {false: 'Post', true: 'Poll'},
                  onChanged:
                      (poll) => setState(() {
                        _isPoll = poll;
                        _error = null;
                      }),
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
                  decoration: InputDecoration(
                    labelText: _isPoll ? 'Question' : 'Title',
                    hintText:
                        _isPoll
                            ? 'What would you like to ask everyone?'
                            : 'What do you want to talk about?',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_isPoll) ..._buildOptions(theme),
                TextField(
                  controller: _contentController,
                  enabled: !_isPosting,
                  maxLength: _maxContent,
                  minLines: _isPoll ? 2 : 6,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText:
                        _isPoll
                            ? 'A few words (optional)'
                            : 'Your story or question',
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
