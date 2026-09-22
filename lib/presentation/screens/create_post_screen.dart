import 'package:flutter/material.dart';
import '../../data/models/category.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedCategoryId;
  bool _isAnonymous = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  Future<void> _publishPost() async {  
  final title = _titleController.text.trim();
  final content = _contentController.text.trim();

  if (_selectedCategoryId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please choose a category.'),
      ),
    );
    return;
  }

  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a title.'),
      ),
    );
    return;
  }

  if (content.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please write something to share.'),
      ),
    );
    return;
  }

try {
  await _firestore.collection('posts').add({
    'authorId': 'current_user',
    'isAnonymous': _isAnonymous,
    'displayName': _isAnonymous ? 'Anonymous' : 'Community Member',
    'categoryId': _selectedCategoryId,
    'title': title,
    'content': content,
    'timestamp': FieldValue.serverTimestamp(),
    'flagCount': 0,
  });

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Post published successfully.'),
    ),
  );

  Navigator.pop(context);
} catch (error) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Unable to publish post. Please try again.'),
    ),
  );
}}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share with the community',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Share your thoughts, experiences, or questions with other women.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),

Text(
  'Category',
  style: theme.textTheme.labelLarge,
),
const SizedBox(height: AppSpacing.sm),

DropdownButtonFormField<String>(
  value: _selectedCategoryId,
  decoration: const InputDecoration(
    hintText: 'Choose a category',
  ),
  items: AppCategories.all.map((category) {
    return DropdownMenuItem<String>(
      value: category.id,
      child: Text(category.name),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedCategoryId = value;
    });
  },
),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Title',
              style: theme.textTheme.labelLarge,
            ),
            Container(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  ),
  decoration: BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: Border.all(
      color: theme.dividerColor,
    ),
  ),
  child: Row(
    children: [
      Icon(
        Icons.visibility_off_outlined,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post anonymously',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your name will not be shown with this post.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      Switch(
        value: _isAnonymous,
        onChanged: (value) {
          setState(() {
            _isAnonymous = value;
          });
        },
      ),
    ],
  ),
),

const SizedBox(height: AppSpacing.xl),

Text(
  'Title',
  style: theme.textTheme.labelLarge,
),
            const SizedBox(height: AppSpacing.sm),

            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Give your post a title',
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Text(
              'Your thoughts',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),

            TextField(
              controller: _contentController,
              minLines: 6,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What would you like to share?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
              ),
            ),

            SizedBox(
  width: double.infinity,
  height: AppSpacing.buttonHeight,
  child: FilledButton(
    onPressed: () {
      debugPrint('PUBLISH BUTTON PRESSED');
      _publishPost();
    },
    child: const Text('Publish Post'),
  ),
),

const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}