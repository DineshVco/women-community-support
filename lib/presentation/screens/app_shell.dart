import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../widgets/ios.dart';
import 'care/care_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// The signed-in app: Discuss, Care and Me under an iOS-style tab bar that
/// is translucent and blurred (content scrolls under it). Connect joins
/// between Discuss and Care once it exists. "Get help" lives in Care.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

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
    final palette = context.palette;

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
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        backgroundColor: barColor(context),
        activeColor: palette.text,
        inactiveColor: palette.textSecondary,
        border: hairline(context, top: true),
        iconSize: 26,
        onTap: (value) {
          if (value != _index) AppHaptics.selection();
          setState(() {
            _index = value;
            _opened.add(value);
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2),
            activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
            label: 'Discuss',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.heart),
            activeIcon: Icon(CupertinoIcons.heart_fill),
            label: 'Care',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
