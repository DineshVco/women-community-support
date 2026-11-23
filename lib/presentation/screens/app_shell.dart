import 'dart:async';
import 'dart:ui' show ImageFilter;

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

  /// The tab bar: translucent and blurred (content scrolls under it). The
  /// active tab shows its filled icon and its name in a soft blush pill;
  /// the others show only the icon. The Me tab shows her chat avatar
  /// ([meAvatarId]), or the cat when she has not chosen one.
  static Widget tabBar(
    BuildContext context, {
    required int index,
    required ValueChanged<int> onTap,
    String? meAvatarId,
  }) {
    return LoomaTabBar(
      index: index,
      onTap: onTap,
      tabs: [
        const TabSpec(
          label: 'Discuss',
          icon: Icon(AppIcons.discuss),
          activeIcon: Icon(AppIcons.discussActive),
        ),
        const TabSpec(
          label: 'Care',
          icon: Icon(AppIcons.care),
          activeIcon: Icon(AppIcons.careActive),
        ),
        // Last tab, "Me", with her avatar (never a label when inactive).
        TabSpec(
          label: 'Me',
          icon: MeTabIcon(avatarId: meAvatarId, active: false),
          activeIcon: MeTabIcon(avatarId: meAvatarId, active: true),
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

/// One tab: its name (always read out) and its icons.
class TabSpec {
  const TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final Widget icon;
  final Widget activeIcon;
}

/// Looma's tab bar: see-through and blurred, a hairline on top, one row of
/// tabs, each an icon with its name under it; the active one sits in a soft
/// blush pill. Each tab is a full-height tap area (at least 56 px). Screen
/// readers hear every tab's name, selected or not.
class LoomaTabBar extends StatelessWidget {
  const LoomaTabBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.tabs,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<TabSpec> tabs;

  /// At least 56; taller with large text so icon and name both fit.
  static double heightFor(TextScaler scaler) {
    final content = 24 + 2 + scaler.scale(13) * 1.2 + 8 + 8;
    return content < 56 ? 56 : content;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: barColor(context),
            border: hairline(context, top: true),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: SizedBox(
              height: heightFor(MediaQuery.textScalerOf(context)),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _TabItem(
                        spec: tabs[i],
                        active: i == index,
                        index: i,
                        count: tabs.length,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.active,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final TabSpec spec;
  final bool active;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.of(context, AppMotion.medium);
    final color = active ? palette.text : palette.tabInactive;

    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: spec.label,
      hint: 'Tab ${index + 1} of $count',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('tab-${spec.label}'),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              key: ValueKey('tab-pill-${spec.label}'),
              duration: duration,
              curve: AppMotion.enter,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color:
                    active
                        ? palette.tabPill
                        : palette.tabPill.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(18),
              ),
              // Icon over its name; the active pill wraps both.
              child: IconTheme.merge(
                data: IconThemeData(size: 24, color: color),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    active ? spec.activeIcon : spec.icon,
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        spec.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                          height: 1.2,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  /// The avatar; with its 2 px ring it is 24 px, like the other icons.
  static const double size = 20;

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
