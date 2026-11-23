import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/chat_profile.dart';
import '../../data/repositories/chat_repository.dart';
import '../widgets/cat_avatar.dart';
import '../widgets/ios.dart';
import 'care/care_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../../core/theme/app_icons.dart';

/// The signed-in app: Discuss, Care and Me under an iOS-style tab bar that
/// is translucent and blurred (content scrolls under it). Connect joins
/// between Discuss and Care once it exists. "Get help" lives in Care.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// The tab bar: translucent and blurred (content scrolls under it), the
  /// active tab with a filled icon on a soft blush pill.
  /// The Me tab shows her chat avatar ([meAvatarId]); the cat when she
  /// has not chosen one yet.
  static CupertinoTabBar tabBar(
    BuildContext context, {
    required int index,
    required ValueChanged<int> onTap,
    String? meAvatarId,
  }) {
    final palette = context.palette;
    BottomNavigationBarItem item(
      IconData icon,
      IconData active,
      String label,
    ) => BottomNavigationBarItem(
      icon: TabIcon(icon: icon, active: false),
      activeIcon: TabIcon(icon: active, active: true),
      label: label,
    );
    return CupertinoTabBar(
      currentIndex: index,
      // See-through colour: CupertinoTabBar blurs what is behind it.
      backgroundColor: barColor(context),
      activeColor: palette.text,
      inactiveColor: palette.textSecondary,
      border: hairline(context, top: true),
      iconSize: 24,
      height: 56,
      onTap: onTap,
      items: [
        item(AppIcons.discuss, AppIcons.discussActive, 'Discuss'),
        item(AppIcons.care, AppIcons.careActive, 'Care'),
        // Last tab, label "Me", with her avatar.
        BottomNavigationBarItem(
          icon: MeTabIcon(avatarId: meAvatarId, active: false),
          activeIcon: MeTabIcon(avatarId: meAvatarId, active: true),
          label: 'Me',
        ),
      ],
    );
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Her chat avatar for the Me tab (null until loaded, or if none).
  String? _avatarId;
  StreamSubscription<ChatProfile?>? _profile;

  @override
  void initState() {
    super.initState();
    ChatRepository? chat;
    try {
      chat = context.read<ChatRepository>();
    } on ProviderNotFoundException {
      chat = null;
    }
    // If it cannot load, the Me tab simply shows the cat.
    _profile = chat?.watchMine().listen(
      (p) => setState(() => _avatarId = p?.avatarId),
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _profile?.cancel();
    super.dispose();
  }

  /// Tabs are built the first time they are opened (then kept), so each
  /// one's entrance plays when she first sees it.
  final Set<int> _opened = {0};

  static const List<Widget> _tabs = [
    HomeScreen(),
    CareScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Content runs under the translucent tab bar.
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _opened.contains(i) ? _tabs[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppShell.tabBar(
        context,
        index: _index,
        meAvatarId: _avatarId,
        onTap: (value) {
          if (value != _index) AppHaptics.selection();
          setState(() {
            _index = value;
            _opened.add(value);
          });
        },
      ),
    );
  }
}

/// A tab icon. The active one sits on a soft blush pill (it fades in, or
/// just appears with Reduce motion).
class TabIcon extends StatelessWidget {
  const TabIcon({super.key, required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color:
            active
                ? palette.blush.withValues(alpha: dark ? 0.28 : 0.45)
                : palette.blush.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon),
    );
  }
}

/// The Me tab: her chat avatar (or the cat) in a small circle, with a soft
/// blush ring when the tab is active. Read out as "Me" (the tab label), not
/// as the avatar.
class MeTabIcon extends StatelessWidget {
  const MeTabIcon({super.key, required this.avatarId, required this.active});

  final String? avatarId;
  final bool active;

  static const double size = 26;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final id =
        avatarId != null && CatAvatars.isValid(avatarId!)
            ? avatarId!
            : CatAvatars.fallback;
    return ExcludeSemantics(
      child: AnimatedContainer(
        key: const ValueKey('me-tab-ring'),
        duration: AppMotion.of(context, AppMotion.medium),
        curve: AppMotion.enter,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 2,
            color: active ? palette.blush : palette.blush.withValues(alpha: 0),
          ),
        ),
        child: ClipOval(child: CatAvatar(id: id, size: size)),
      ),
    );
  }
}
