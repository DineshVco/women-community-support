import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/connect.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/chat_profile.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../providers/app_settings.dart';
import '../providers/theme_provider.dart';
import '../widgets/adaptive.dart';
import '../widgets/card_picture.dart';
import '../widgets/cat_avatar.dart';
import '../widgets/ios.dart';
import '../widgets/looma_card.dart';
import '../widgets/content_width.dart';
import '../widgets/quick_exit_button.dart';
import '../widgets/app_lock_gate.dart';
import '../../data/encrypted_box.dart';
import 'care/care_screen.dart' show openJournal;
import 'me/app_lock_settings_screen.dart';
import 'me/chat_profile_editor.dart';
import 'me/my_reports_screen.dart';
import 'me/open_to_chat_tile.dart';
import 'me/post_list_screen.dart';
import 'me/privacy_centre_screen.dart';
import 'me/safety_plan_screen.dart' show openSafetyPlan;
import 'moderator_screen.dart';
import 'onboarding_screen.dart';
import '../../core/theme/app_icons.dart';

/// The "Me" tab, top to bottom:
///  chat profile (avatar, alias, bio, badge) · Open to chat · interests ·
///  my space · moderation (moderators only) · privacy centre · settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// Easy to find, at the end of Me under "Account".
  static const String deleteLabel = 'Delete my account and data';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final PostRepository _repo;
  late final ChatRepository _chat;
  late final Stream<ChatProfile?> _chatProfile;
  late final Stream<UserProfile> _account;
  late final Stream<bool> _founding;
  late final Future<bool> _isModerator;

  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<PostRepository>();
    _chat = context.read<ChatRepository>();
    _chatProfile = _chat.watchMine();
    _account = _repo.watchProfile();
    _founding = _repo.watchFoundingMember();
    _isModerator = _repo.isModerator();
    // Older accounts get a sign-up time now (starts the 24 hour wait).
    _repo.ensureCreatedAt().catchError((Object _) {});
  }

  Future<void> _editChatProfile(ChatProfile? current) {
    final user = FirebaseAuth.instance.currentUser;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ChatProfileEditor(
              initial: current,
              email: user?.email,
              displayName: user?.displayName,
              onSave:
                  (draft) => _chat.save(
                    alias: draft.alias,
                    avatarId: draft.avatarId,
                    bio: draft.bio,
                    interests: draft.interests,
                    lookingFor: draft.lookingFor,
                  ),
            ),
      ),
    );
  }

  Future<void> _setOpen(bool open) async {
    AppHaptics.selection();
    setState(() => _switching = true);
    try {
      await _chat.setOpen(open);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not change this. Try again in a moment.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You can sign back in at any time.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed) return;

    // AuthGate notices the change and shows the sign-in flow.
    await _repo.signOut();
  }

  Future<void> _chooseDisguise(AppSettings settings) async {
    final picked = await showOptionsSheet<QuickExitScreen>(
      context,
      title: 'Quick exit disguise',
      message: 'What Quick exit shows instead of Looma.',
      options: [
        for (final s in QuickExitScreen.values)
          SheetOption(
            value: s,
            label: s.label,
            isDefault: s == settings.quickExitScreen,
          ),
      ],
    );
    if (picked != null) await settings.setQuickExitScreen(picked);
  }

  Future<void> _editCity(AppSettings settings) async {
    final city = await showTextDialog(
      context,
      title: 'Weather city',
      initial: settings.weatherCity,
      placeholder: AppSettings.defaultCity,
    );
    if (city != null) await settings.setWeatherCity(city);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final lock = AppLockScope.maybeOf(context);

    return StreamBuilder<ChatProfile?>(
      stream: _chatProfile,
      builder: (context, chatSnapshot) {
        final profile = chatSnapshot.data;
        final loaded =
            chatSnapshot.hasData ||
            chatSnapshot.connectionState == ConnectionState.active;

        return LargeTitleScaffold(
          // Title and Quick exit on one row, like Discuss and Care.
          title: 'Me',
          trailing: const QuickExitButton(),
          slivers: [
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ───────── Chat profile ─────────
                    _Card(
                      child: StreamBuilder<bool>(
                        stream: _founding,
                        builder:
                            (context, founding) => ChatProfileHeader(
                              profile: profile,
                              loading: !loaded && !chatSnapshot.hasError,
                              foundingMember: founding.data ?? false,
                              onEdit: () => _editChatProfile(profile),
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ───────── Interests ─────────
                    GroupedSection(
                      header: 'Interests & looking for',
                      icon: AppIcons.sectionInterests,
                      children: [
                        _InterestsSummary(
                          profile: profile,
                          onEdit: () => _editChatProfile(profile),
                        ),
                      ],
                    ),

                    // ───────── Your space ─────────
                    GroupedSection(
                      header: 'Your space',
                      icon: AppIcons.sectionSpace,
                      children: [
                        GroupedRow(
                          icon: AppIcons.myPosts,
                          title: 'My posts',
                          subtitle: 'Only you can see this list',
                          onTap:
                              () => _push(
                                PostListScreen(
                                  title: 'My posts',
                                  load: _repo.myPosts,
                                  note:
                                      'Only you can see this list. Others '
                                      'only ever see a random alias.',
                                  emptyTitle: 'No posts yet',
                                  emptyMessage:
                                      'Discussions you start will be listed '
                                      'here.',
                                ),
                              ),
                        ),
                        GroupedRow(
                          icon: AppIcons.bookmark,
                          title: 'Saved posts',
                          onTap:
                              () => _push(
                                PostListScreen(
                                  title: 'Saved posts',
                                  load: _repo.savedPosts,
                                  emptyTitle: 'Nothing saved yet',
                                  emptyMessage:
                                      'Tap the bookmark at the top of a '
                                      'discussion, or press and hold a post, '
                                      'to keep it here.',
                                ),
                              ),
                        ),
                        GroupedRow(
                          icon: AppIcons.safety,
                          title: 'Safety plan',
                          subtitle:
                              EncryptedBox.supported
                                  ? 'Contacts, a safe place, a code word'
                                  : EncryptedBox.webNote,
                          enabled: EncryptedBox.supported,
                          onTap: () => openSafetyPlan(context),
                        ),
                        if (EncryptedBox.supported)
                          GroupedRow(
                            icon: AppIcons.book,
                            title: 'My journal',
                            subtitle: 'Private notes, only on this phone',
                            onTap: () => openJournal(context),
                          ),
                      ],
                    ),

                    // ───────── Moderation ─────────
                    FutureBuilder<bool>(
                      future: _isModerator,
                      builder: (context, snapshot) {
                        if (snapshot.data != true) {
                          return const SizedBox.shrink();
                        }
                        return GroupedSection(
                          header: 'Moderation',
                          children: [
                            GroupedRow(
                              icon: AppIcons.shieldCheck,
                              title: 'Report queue',
                              onTap: () => _push(const ModeratorScreen()),
                            ),
                          ],
                        );
                      },
                    ),

                    // ───────── Privacy and safety ─────────
                    StreamBuilder<UserProfile>(
                      stream: _account,
                      builder: (context, account) {
                        final joinedAt = account.data?.createdAt;
                        return GroupedSection(
                          header: 'Privacy & safety',
                          icon: AppIcons.sectionPrivacy,
                          children: [
                            OpenToChatTile.rowFor(
                              profile: profile,
                              joinedAt: joinedAt,
                              busy: _switching,
                              onChanged: _setOpen,
                              subtitle:
                                  OpenToChatTile.noteFor(
                                    profile: profile,
                                    joinedAt: joinedAt,
                                  ) ??
                                  OpenToChatTile.explanation,
                            ),
                            const GroupedRow(
                              icon: AppIcons.blocked,
                              title: 'Blocked list',
                              trailing: ComingSoonTag(),
                            ),
                            GroupedRow(
                              icon: AppIcons.flag,
                              title: 'My reports',
                              onTap: () => _push(const MyReportsScreen()),
                            ),
                            // Readable, with a tag (not greyed out).
                            const GroupedRow(
                              icon: AppIcons.envelope,
                              title: 'My requests',
                              trailing: ComingSoonTag(),
                            ),
                            GroupedRow(
                              icon: AppIcons.lock,
                              title: 'App lock',
                              value: (lock?.enabled ?? false) ? 'On' : 'Off',
                              onTap: () => _push(const AppLockSettingsScreen()),
                            ),
                            GroupedRow(
                              icon: AppIcons.eyeSlash,
                              title: 'Quick exit disguise',
                              value: settings.quickExitScreen.label,
                              onTap: () => _chooseDisguise(settings),
                            ),
                            if (settings.quickExitScreen ==
                                QuickExitScreen.weather)
                              GroupedRow(
                                icon: AppIcons.weather,
                                title: 'Weather city',
                                value: settings.weatherCity,
                                onTap: () => _editCity(settings),
                              ),
                            GroupedRow(
                              icon: AppIcons.shieldCheck,
                              title: 'Practice Quick exit',
                              onTap: () => QuickExit.practice(context),
                            ),
                            GroupedRow(
                              icon: AppIcons.eye,
                              title: 'Who can see what',
                              onTap: () => _push(const PrivacyCentreScreen()),
                            ),
                          ],
                        );
                      },
                    ),

                    // ───────── Appearance ─────────
                    SettingsSection(settings: settings),

                    // ───────── Account ─────────
                    GroupedSection(
                      header: 'Account',
                      children: [
                        GroupedRow(
                          icon: AppIcons.guides,
                          title: 'View introduction',
                          onTap:
                              () => _push(
                                OnboardingScreen(
                                  viewOnly: true,
                                  onGetStarted:
                                      () => Navigator.of(context).pop(),
                                  onSignIn: () => Navigator.of(context).pop(),
                                ),
                              ),
                        ),
                        GroupedRow(
                          icon: AppIcons.signOut,
                          title: 'Sign out',
                          onTap: _signOut,
                        ),
                        GroupedRow(
                          icon: AppIcons.delete,
                          title: ProfileScreen.deleteLabel,
                          subtitle:
                              'Deletes your posts, chats and private data. '
                              'You confirm first.',
                          destructive: true,
                          onTap:
                              () => _push(
                                const PrivacyCentreScreen(deleteFirst: true),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Pieces ─────────────────────────

/// How the profile card splits: the picture takes the right 40%; the
/// alias and "Edit chat profile" keep to the left of it.
class ProfileCardLayout {
  ProfileCardLayout._();

  static const double pictureWidth = 0.4;

  /// The text stops where the picture starts to show.
  static double textRightInset(double cardWidth) =>
      cardWidth * pictureWidth * (1 - CardPicture.clearUntil);
}

/// A rounded card on the grouped background (same inset as the lists).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The cat moment at the top of Me: blush to cream, with a magnolia
    // painting on the right (a soft gradient until the picture is added).
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LoomaCard(
        gradient: LinearGradient(colors: palette.profileGradient),
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: ProfileCardLayout.pictureWidth,
                  heightFactor: 1,
                  child: CardPicture(
                    key: const ValueKey('profile-picture'),
                    asset: CardPictures.magnolia,
                    fallback: [palette.profileGradient.last, palette.tabPill],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder:
                  (context, box) => Padding(
                    // The text keeps to the left, clear of the picture.
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.md,
                      right: ProfileCardLayout.textRightInset(box.maxWidth),
                    ),
                    child: child,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar, alias, bio and badge, or an invitation to set them up.
class ChatProfileHeader extends StatelessWidget {
  const ChatProfileHeader({
    super.key,
    required this.profile,
    required this.onEdit,
    this.foundingMember = false,
    this.loading = false,
  });

  final ChatProfile? profile;
  final VoidCallback onEdit;
  final bool foundingMember;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final p = profile;

    final badge =
        foundingMember
            ? Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: palette.blush,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                '✦ Founding member',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.onBlush,
                ),
              ),
            )
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Change avatar',
            child: GestureDetector(
              onTap: loading ? null : onEdit,
              child: CatAvatar(
                id: p?.avatarId ?? CatAvatars.fallback,
                size: 72,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loading)
                  Text('Loading…', style: theme.textTheme.bodyMedium)
                else if (p == null) ...[
                  Text(
                    'Your chat profile',
                    style: AppTypography.heading(24, palette.text),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Pick an avatar and a nickname for Connect. It is never '
                    'linked to your posts.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ] else ...[
                  Text(p.alias, style: AppTypography.heading(24, palette.text)),
                  if (p.bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      p.bio,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ],
                if (badge != null) badge,
                if (!loading)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(AppIcons.edit, size: 16),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: palette.text,
                      ),
                      label: Text(
                        p == null ? 'Set up chat profile' : 'Edit chat profile',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestsSummary extends StatelessWidget {
  const _InterestsSummary({required this.profile, required this.onEdit});

  final ChatProfile? profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = profile;
    final ids = [...?p?.interests];
    final looking = [...?p?.lookingFor];

    Widget tag(String text, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.chipFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.text),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: palette.text),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child:
          ids.isEmpty && looking.isEmpty
              ? Text(
                'Choose up to 5 interests and what you are looking for, so '
                'women who relate can find you.',
                style: TextStyle(fontSize: 15, color: palette.textSecondary),
              )
              : Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final id in ids)
                    tag(
                      ConnectOptions.labelFor(ConnectOptions.interests, id),
                      AppIcons.interest(id),
                    ),
                  for (final id in looking)
                    tag(
                      ConnectOptions.labelFor(ConnectOptions.lookingFor, id),
                      AppIcons.interest(id),
                    ),
                ],
              ),
    );
  }
}

/// Appearance, Gentle mode, Reduce motion and Quick exit, as grouped lists.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(16, 12, 16, 12);
    final theme = context.watch<ThemeProvider>();

    return Column(
      children: [
        GroupedSection(
          header: 'Appearance',
          children: [
            Padding(
              padding: padding,
              child: LoomaSegmented<ThemeMode>(
                value: theme.themeMode,
                options: const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                onChanged: theme.setThemeMode,
              ),
            ),
            GroupedSwitchRow(
              icon: AppIcons.gentle,
              title: 'Gentle mode',
              subtitle: 'Hides numbers like replies and "me too" counts.',
              value: settings.gentleMode,
              onChanged: settings.setGentleMode,
            ),
            GroupedSwitchRow(
              icon: AppIcons.reduceMotion,
              title: 'Reduce motion',
              subtitle:
                  'Turns off animations in Looma. Your phone\'s own setting '
                  'also works.',
              value: settings.reduceMotion,
              onChanged: settings.setReduceMotion,
            ),
          ],
        ),
      ],
    );
  }
}
