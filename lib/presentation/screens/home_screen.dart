import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

import '../../data/models/post.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Stream<List<Post>> get _postsStream {
  return FirebaseFirestore.instance
      .collection('posts')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(Post.fromFirestore)
            .toList(),
      );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
            AppSpacing.screenHorizontal,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
  // Header
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'HerCircle',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ],
  ),

  const SizedBox(height: AppSpacing.xxl),

              // Greeting
              Text(
               'Good morning 👋',
                style: Theme.of(context).textTheme.headlineLarge,
               ),

              const SizedBox(height: AppSpacing.xs),

              Text(
              'Find a safe space to share, learn, and connect.',
               style: Theme.of(context).textTheme.bodyMedium,
               ),

              const SizedBox(height: AppSpacing.xxl),

              // Search
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search discussions...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Categories
              Text(
                'Explore categories',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.md),

              _CategoryGrid(),

              const SizedBox(height: AppSpacing.xxxl),

              // Community feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Community discussions',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See all'),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

StreamBuilder<List<Post>>(
  stream: _postsStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (snapshot.hasError) {
      return Text(
        'Unable to load discussions.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final posts = snapshot.data ?? [];

    if (posts.isEmpty) {
  return _EmptyFeed();
}
    return Column(
      children: posts
          .map(
            (post) => Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
              ),
              child: PostCard(
                post: post,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post),
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
    );
  },
),
            ],
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: _BottomNavigationBar(),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = [
  (
    'Health & Wellness',
    Icons.favorite_outline_rounded,
    AppColors.health,
    AppColors.healthSoft,
  ),
  (
    'Education',
    Icons.menu_book_outlined,
    AppColors.education,
    AppColors.educationSoft,
  ),
  (
    'Career Development',
    Icons.work_outline_rounded,
    AppColors.career,
    AppColors.careerSoft,
  ),
  (
    'Personal Safety',
    Icons.shield_outlined,
    AppColors.safety,
    AppColors.safetySoft,
  ),
];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
          color: Theme.of(context).dividerColor,
         ),
          boxShadow: const [
          BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
         ),
       ],
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                color: category.$4,
                shape: BoxShape.circle,
               ),
                child: Icon(
                  category.$2,
                  color: category.$3,
                  size: 21,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                category.$1,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(AppRadius.xl),
  border: Border.all(
    color: Theme.of(context).dividerColor,
  ),
  boxShadow: const [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ],
),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No discussions yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Be the first to start a conversation with the community.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BottomNavigationBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
      onDestinationSelected: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostScreen(),
            ),
          );
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline_rounded),
          selectedIcon: Icon(Icons.add_circle_rounded),
          label: 'Post',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Categories',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}