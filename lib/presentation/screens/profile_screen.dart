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
import '../widgets/cat_avatar.dart';
import '../widgets/ios.dart';
import '../widgets/content_width.dart';
import '../widgets/quick_exit_button.dart';
import '../widgets/app_lock_gate.dart';
import 'me/app_lock_settings_screen.dart';
import 'me/chat_profile_editor.dart';
import 'me/my_reports_screen.dart';
import 'me/open_to_chat_tile.dart';
import 'me/post_list_screen.dart';
import 'me/privacy_centre_screen.dart';
import 'moderator_screen.dart';
import '../../core/theme/app_icons.dart';

/// The "Me" tab, top to bottom:
///  chat profile (avatar, alias, bio, badge) · Open to chat · interests ·
///  my space · moderation (moderators only) · privacy centre · settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
          title: 'Me',
          trailing: const QuickExitButton(),
          slivers: [
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),

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

                    // ───────── Open to chat ─────────
                    StreamBuilder<UserProfile>(
                      stream: _account,
                      builder:
                          (context, account) => OpenToChatTile(
                            profile: profile,
                            joinedAt: account.data?.createdAt,
                            busy: _switching,
                            onChanged: _setOpen,
                          ),
                    ),

                    // ───────── Interests ─────────
                    GroupedSection(
                      header: 'Interests and looking for',
                      children: [
                        _InterestsSummary(
                          profile: profile,
                          onEdit: () => _editChatProfile(profile),
                        ),
                      ],
                    ),

                    // ───────── My space ─────────
                    GroupedSection(
                      header: 'My space',
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
                          icon: AppIcons.flag,
                          title: 'My reports',
                          onTap: () => _push(const MyReportsScreen()),
                        ),
                        const GroupedRow(
                          icon: AppIcons.envelope,
                          title: 'My requests',
                          subtitle: 'Arrives with Connect',
                          enabled: false,
                        ),
                        const GroupedRow(
                          icon: AppIcons.blocked,
                          title: 'Blocked list',
                          subtitle: 'Arrives with Connect',
                          enabled: false,
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

                    // ───────── Privacy centre ─────────
                    GroupedSection(
                      header: 'Privacy centre',
                      children: [
                        GroupedRow(
                          icon: AppIcons.lock,
                          title: 'App lock',
                          value: (lock?.enabled ?? false) ? 'On' : 'Off',
                          onTap: () => _push(const AppLockSettingsScreen()),
                        ),
                        GroupedRow(
                          icon: AppIcons.eye,
                          title: 'Who can see what',
                          onTap: () => _push(const PrivacyCentreScreen()),
                        ),
                        GroupedRow(
                          icon: AppIcons.delete,
                          title: 'Delete my account and data',
                          destructive: true,
                          onTap: () => _push(const PrivacyCentreScreen()),
                        ),
                      ],
                    ),

                    // ───────── Settings ─────────
                    SettingsSection(settings: settings),

                    // ───────── Sign out ─────────
                    GroupedSection(
                      children: [
                        GroupedRow(
                          icon: AppIcons.signOut,
                          title: 'Sign out',
                          destructive: true,
                          onTap: _signOut,
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

/// A rounded card on the grouped background (same inset as the lists).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
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
                    child: TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: palette.text,
                      ),
                      child: Text(
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

    Widget tag(String text, {bool looking = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: looking ? palette.blushTint : palette.softFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 14, color: palette.text)),
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
                    tag(ConnectOptions.labelFor(ConnectOptions.interests, id)),
                  for (final id in looking)
                    tag(
                      ConnectOptions.labelFor(ConnectOptions.lookingFor, id),
                      looking: true,
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
        GroupedSection(
          header: 'Quick exit',
          children: [
            Padding(
              padding: padding,
              child: LoomaSegmented<QuickExitScreen>(
                value: settings.quickExitScreen,
                options: {for (final s in QuickExitScreen.values) s: s.label},
                onChanged: settings.setQuickExitScreen,
              ),
            ),
            GroupedRow(
              icon: AppIcons.weather,
              title: 'Weather city',
              value: settings.weatherCity,
              onTap: () => _editCity(context),
            ),
            GroupedRow(
              icon: AppIcons.eyeSlash,
              title: 'Practice Quick exit',
              onTap: () => QuickExit.practice(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editCity(BuildContext context) async {
    final city = await showTextDialog(
      context,
      title: 'Weather city',
      initial: settings.weatherCity,
      placeholder: AppSettings.defaultCity,
    );
    if (city != null) await settings.setWeatherCity(city);
  }
}
