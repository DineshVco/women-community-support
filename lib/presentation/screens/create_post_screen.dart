import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/content_filter.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/category.dart';
import '../../data/repositories/post_repository.dart';
import '../widgets/adaptive.dart';
import '../widgets/content_width.dart';
import '../widgets/looma_button.dart';
import '../widgets/ios.dart';
import 'help_screen.dart';
import '../../core/theme/app_icons.dart';
import '../widgets/quick_exit_button.dart';

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

  static const String postNote =
      'Your name is never shown. You get a random alias for this '
      'discussion only.';

  /// The gentle line when she taps Post before choosing a category.
  static const String chooseCategory = 'Choose a category';

  /// A counter (such as 0/120) shows only from this share of the limit.
  static const double counterFrom = 0.8;

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

  /// She tapped Post without a category: a gentle hint under "Category".
  bool _askCategory = false;
  final GlobalKey _categoryKey = GlobalKey(debugLabel: 'category');

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
    // The Post button wakes up as she writes.
    _titleController.addListener(_changed);
    _contentController.addListener(_changed);
    for (final c in _options) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Everything a post (or poll) needs is there: a category, a title and a
  /// story (a poll: its question and 2 answers). Until then the Post button
  /// looks faded.
  bool get _ready {
    if (_categoryId == null) return false;
    if (_titleController.text.trim().isEmpty) return false;
    return _isPoll
        ? _optionTexts.length >= 2
        : _contentController.text.trim().isNotEmpty;
  }

  /// Shows a counter such as 104/120 only when she is close to the limit.
  static Widget? _nearLimit(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null ||
        currentLength < maxLength * CreatePostScreen.counterFrom) {
      return null;
    }
    return Text(
      '$currentLength/$maxLength',
      style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
    );
  }

  /// Soft borders, and a warm focus colour.
  InputDecoration _field(
    AppPalette palette, {
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      enabledBorder: border(palette.border, 1),
      border: border(palette.border, 1),
      disabledBorder: border(palette.border, 1),
      focusedBorder: border(palette.accent, 1.6),
      floatingLabelStyle: TextStyle(color: palette.accent),
    );
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

    // No category yet: a gentle nudge, and the chips scroll into view.
    if (_categoryId == null) {
      setState(() {
        _askCategory = true;
        _error = null;
      });
      final chips = _categoryKey.currentContext;
      if (chips != null) {
        Scrollable.ensureVisible(
          chips,
          alignment: 0.2,
          duration: AppMotion.of(context, AppMotion.medium),
        );
      }
      return;
    }

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
      // The feed gives the light haptic and the "Posted" confirmation.
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
                  buildCounter: _nearLimit,
                  decoration: _field(context.palette, label: 'Answer ${i + 1}'),
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
                  icon: const Icon(AppIcons.removeCircle),
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
                    : () => setState(
                      () => _options.add(
                        TextEditingController()..addListener(_changed),
                      ),
                    ),
            icon: const Icon(AppIcons.addCircle, size: 18),
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
    final ready = _ready;

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: _isPoll ? 'New poll' : 'New post',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        child: ContentWidth(
          // The Post button sits under the form, so it stays above the
          // keyboard while she types.
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.screenHorizontal,
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PrivacyNote(
                        text:
                            _categoryId == AppCategories.askLoomaId
                                ? CreatePostScreen.askNote
                                : _isPoll
                                ? CreatePostScreen.pollNote
                                : CreatePostScreen.postNote,
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
                      Text(
                        'Category',
                        key: _categoryKey,
                        style: theme.textTheme.labelLarge,
                      ),
                      if (_askCategory && _categoryId == null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Semantics(
                          liveRegion: true,
                          child: Row(
                            key: const ValueKey('choose-category'),
                            children: [
                              Icon(
                                AppIcons.arrowUp,
                                size: 14,
                                color: palette.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  CreatePostScreen.chooseCategory,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final category in AppCategories.all)
                            _CategoryChip(
                              category: category,
                              selected: _categoryId == category.id,
                              onTap:
                                  _isPosting
                                      ? null
                                      : () {
                                        AppHaptics.selection();
                                        setState(() {
                                          _categoryId = category.id;
                                          _askCategory = false;
                                        });
                                      },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        key: const ValueKey('post-title'),
                        controller: _titleController,
                        enabled: !_isPosting,
                        maxLength: _maxTitle,
                        buildCounter: _nearLimit,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        // Newsreader, like a heading.
                        style: AppTypography.heading(20, palette.text),
                        decoration: _field(
                          palette,
                          label: _isPoll ? 'Question' : 'Title',
                          hint:
                              _isPoll
                                  ? 'What would you like to ask everyone?'
                                  : 'What do you want to talk about?',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_isPoll) ..._buildOptions(theme),
                      TextField(
                        key: const ValueKey('post-story'),
                        controller: _contentController,
                        enabled: !_isPosting,
                        maxLength: _maxContent,
                        buildCounter: _nearLimit,
                        minLines: _isPoll ? 2 : 6,
                        maxLines: 12,
                        textCapitalization: TextCapitalization.sentences,
                        // Figtree, the reading font.
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFamily: AppTypography.bodyFont,
                          color: palette.text,
                        ),
                        decoration: _field(
                          palette,
                          label:
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
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                ),
                // Faded until a category, a title and a story are there
                // (still tappable: it then says what is missing, gently).
                child: Semantics(
                  hint:
                      ready
                          ? null
                          : _isPoll
                          ? 'Needs a category, a question and 2 answers'
                          : 'Needs a category, a title and a story',
                  child: AnimatedOpacity(
                    key: const ValueKey('post-button'),
                    opacity: ready || _isPosting ? 1 : 0.4,
                    duration: AppMotion.of(context, AppMotion.fast),
                    child: LoomaButton.primary(
                      label: 'Post',
                      loading: _isPosting,
                      onPressed: _publish,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The privacy note at the top: a soft, warm card with a small lock.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const ValueKey('privacy-note'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.chipFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.lock, size: 15, color: palette.text),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A category choice in the soft colour and icon of the feed's category
/// pills. Not chosen: a light wash of the colour. Chosen: filled, with a
/// check mark and a firm edge.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fill = palette.categoryFill(category.id);
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          key: ValueKey('category-${category.id}'),
          duration: AppMotion.of(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? fill : fill.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.text : palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? AppIcons.check : AppIcons.category(category.id),
                size: 16,
                color: palette.text,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SupportChoice { getHelp, postAnyway }
