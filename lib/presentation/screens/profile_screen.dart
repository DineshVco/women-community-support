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
import '../widgets/content_width.dart';
import '../widgets/looma_button.dart';
import '../widgets/quick_exit_button.dart';
import 'me/chat_profile_editor.dart';
import 'me/my_reports_screen.dart';
import 'me/open_to_chat_tile.dart';
import 'me/post_list_screen.dart';
import 'me/privacy_centre_screen.dart';
import 'moderator_screen.dart';

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
    );
    if (!confirmed) return;

    // AuthGate notices the change and shows the sign-in flow.
    await _repo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        automaticallyImplyLeading: false,
        actions: const [QuickExitButton(), SizedBox(width: AppSpacing.sm)],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: StreamBuilder<ChatProfile?>(
            stream: _chatProfile,
            builder: (context, chatSnapshot) {
              final profile = chatSnapshot.data;
              final loaded =
                  chatSnapshot.hasData ||
                  chatSnapshot.connectionState == ConnectionState.active;

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: [
                  // ───────── Chat profile ─────────
                  StreamBuilder<bool>(
                    stream: _founding,
                    builder:
                        (context, founding) => ChatProfileHeader(
                          profile: profile,
                          loading: !loaded && !chatSnapshot.hasError,
                          foundingMember: founding.data ?? false,
                          onEdit: () => _editChatProfile(profile),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

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
                  const Divider(height: AppSpacing.xl),

                  // ───────── Interests ─────────
                  _Section(
                    title: 'Interests and looking for',
                    child: _InterestsSummary(
                      profile: profile,
                      onEdit: () => _editChatProfile(profile),
                    ),
                  ),

                  // ───────── My space ─────────
                  _Section(
                    title: 'My space',
                    padChild: false,
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.article_outlined,
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
                        _Row(
                          icon: Icons.bookmark_border,
                          title: 'Saved posts',
                          subtitle: 'Tap the bookmark on a discussion',
                          onTap:
                              () => _push(
                                PostListScreen(
                                  title: 'Saved posts',
                                  load: _repo.savedPosts,
                                  emptyTitle: 'Nothing saved yet',
                                  emptyMessage:
                                      'Tap the bookmark at the top of a '
                                      'discussion to keep it here.',
                                ),
                              ),
                        ),
                        _Row(
                          icon: Icons.flag_outlined,
                          title: 'My reports',
                          subtitle: 'What happened to posts you reported',
                          onTap: () => _push(const MyReportsScreen()),
                        ),
                        const _Row(
                          icon: Icons.mail_outline,
                          title: 'My requests',
                          subtitle: 'Arrives with Connect',
                        ),
                        const _Row(
                          icon: Icons.block,
                          title: 'Blocked list',
                          subtitle: 'Arrives with Connect',
                        ),
                      ],
                    ),
                  ),

                  // ───────── Moderation ─────────
                  FutureBuilder<bool>(
                    future: _isModerator,
                    builder: (context, snapshot) {
                      if (snapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return _Section(
                        title: 'Moderation',
                        padChild: false,
                        child: _Row(
                          icon: Icons.shield_outlined,
                          title: 'Report queue',
                          subtitle: 'Review reported posts',
                          onTap: () => _push(const ModeratorScreen()),
                        ),
                      );
                    },
                  ),

                  // ───────── Privacy centre ─────────
                  _Section(
                    title: 'Privacy centre',
                    padChild: false,
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.visibility_outlined,
                          title: 'Who can see what',
                          subtitle: 'Plain words, including the limits',
                          onTap: () => _push(const PrivacyCentreScreen()),
                        ),
                        _Row(
                          icon: Icons.delete_outline,
                          title: 'Delete my account and data',
                          danger: true,
                          onTap: () => _push(const PrivacyCentreScreen()),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            AppSpacing.md,
                            AppSpacing.screenHorizontal,
                            0,
                          ),
                          child: LoomaButton.outline(
                            label: 'Sign out',
                            onPressed: _signOut,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ───────── Settings ─────────
                  _Section(
                    title: 'Settings',
                    padChild: false,
                    divider: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: Text(
                            'Dark mode',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: _ThemeChoice(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SettingsSwitches(settings: settings),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Pieces ─────────────────────────

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
    final theme = Theme.of(context);
    final p = profile;
    final ids = [...?p?.interests];
    final looking = [...?p?.lookingFor];

    if (ids.isEmpty && looking.isEmpty) {
      return Text(
        'Choose up to 5 interests and what you are looking for, so women who '
        'relate can find you.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final id in ids)
          Chip(
            label: Text(ConnectOptions.labelFor(ConnectOptions.interests, id)),
          ),
        for (final id in looking)
          Chip(
            avatar: const Icon(Icons.search, size: 16),
            label: Text(ConnectOptions.labelFor(ConnectOptions.lookingFor, id)),
          ),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {context.watch<ThemeProvider>().themeMode},
        onSelectionChanged: (selection) {
          AppHaptics.selection();
          context.read<ThemeProvider>().setThemeMode(selection.first);
        },
      ),
    );
  }
}

/// Gentle mode and Reduce motion.
class SettingsSwitches extends StatelessWidget {
  const SettingsSwitches({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.screenHorizontal,
    );
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: padding,
          title: const Text('Gentle mode'),
          subtitle: const Text(
            'Hides numbers like replies and "me too" counts.',
          ),
          value: settings.gentleMode,
          onChanged: (value) {
            AppHaptics.selection();
            settings.setGentleMode(value);
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: padding,
          title: const Text('Reduce motion'),
          subtitle: const Text(
            'Turns off animations in Looma. Your phone\'s own setting also '
            'works.',
          ),
          value: settings.reduceMotion,
          onChanged: (value) {
            AppHaptics.selection();
            settings.setReduceMotion(value);
          },
        ),
      ],
    );
  }
}

/// A titled group separated by a hairline.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.padChild = true,
    this.divider = true,
  });

  final String title;
  final Widget child;

  /// False for children (like ListTiles) that already have side padding.
  final bool padChild;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const side = EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: side,
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          padChild ? Padding(padding: side, child: child) : child,
          if (divider) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Null shows the row greyed out (not available yet).
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = danger ? palette.danger : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      enabled: onTap != null,
      leading: Icon(icon, color: color),
      title: Text(title, style: color == null ? null : TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
