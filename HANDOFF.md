# HerCircle redesign: handoff (unfinished, NOT compiled)

Written in a cloud session with no Flutter SDK, so nothing here has been analysed or run.
Run `flutter pub get` then `flutter analyze` first and fix whatever it reports.

## How to apply
1. Unzip over the project root (same folder paths as the repo). Overwrite when asked.
2. DELETE these old files (they were replaced):
   - lib/core/theme/app_shadows.dart
   - lib/presentation/providers/comments_provider.dart
   - lib/presentation/widgets/avatar.dart
   - lib/presentation/widgets/category_chip.dart
   - lib/presentation/widgets/comment_card.dart
3. Add to pubspec.yaml dependencies:  url_launcher: ^6.3.1

## Design decisions (keep these)
- Palette: warm paper neutrals + deep green #1F5F54 (dark mode #7CC4B3). Access with `context.palette`.
- Content-first: flat feed rows with hairlines, no shadows, no gradients, category = small coloured text.
- Anonymity: posts/comments hold NO author id. Authors live in `authors/{postId}` and
  `posts/{id}/commentAuthors/{commentId}`, readable only by the author (see firestore.rules).
  Per-thread alias via AliasGenerator ("Quiet Fox"). Honest claim: anonymous to members and
  moderators, NOT to the Firebase project owner.
- All Firestore access goes through lib/data/repositories/post_repository.dart.
- Feed filters hidden/removed posts client-side (avoids composite indexes).
- Moderators = manual doc `moderators/{uid}` in the Firebase console.
- Known limits: rate limit is posts only (1/min via rules); comment count can be inflated by +1 calls;
  guest accounts are cheap so report spam is possible.

## Already written
core/theme/*, core/utils/*, core/constants/helplines.dart, data/models/*, data/repositories/post_repository.dart,
firestore.rules, widgets/*, screens: auth_gate, auth/signed_out_flow, auth/login_screen, onboarding_screen,
app_shell, home_screen, create_post_screen, help_screen, decoy_screen.

## STILL TO WRITE
1. lib/presentation/screens/post_detail_screen.dart  (constructor: PostDetailScreen({required String postId}))
   - StreamBuilder on repo.watchPost; show removed/hidden message
   - realtime comments via repo.watchComments, one-level replies (reply to a reply attaches to the parent)
   - "Me too" toggle using repo.watchMeToo / repo.setMeToo; Report sheet using ReportReasons.all + repo.reportPost
   - "Author" tag when comment.alias == post.alias; delete post if repo.isMyPost
   - bottom CommentComposer (widgets/comment_composer.dart); block ContentFilter.isDisrespectful
2. lib/presentation/screens/profile_screen.dart (tab "Me"): guest/email label, theme SegmentedButton
   (ThemeProvider.setThemeMode), post count (repo.myPostCount), my reports with outcomes (repo.watchMyReports),
   moderator tile if repo.isModerator(), privacy notice (honest wording above), sign out (confirm; warn guests)
3. lib/presentation/screens/moderator_screen.dart: repo.watchOpenReports, "Keep post" / "Remove post"
   via repo.resolvePostReports, open post to read it
4. lib/main.dart: MultiProvider(ThemeProvider + Provider<PostRepository>), title 'HerCircle',
   theme: AppTheme.light, darkTheme: AppTheme.dark, home: const AuthGate(). Remove CommentsProvider.
5. test/widget_test.dart: update texts ("Welcome back", "Create your account", "Continue as guest");
   add unit tests for AliasGenerator, ContentFilter, Post.fromMap, timeAgo.
6. web/index.html + web/manifest.json: name HerCircle, description, theme colour #1F5F54.
7. firebase.json: add "firestore": {"rules": "firestore.rules"} then `firebase deploy --only firestore:rules`.
8. Firebase console: enable Anonymous sign-in; publish rules; create moderators/{uid}.
9. Verify helpline numbers in lib/core/constants/helplines.dart on official sites.
10. Fonts later: add Newsreader + Atkinson Hyperlegible files, declare in pubspec, then set
    AppTypography.headingFont / bodyFont.
