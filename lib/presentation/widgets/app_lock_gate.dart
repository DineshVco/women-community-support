import 'package:flutter/material.dart';

import '../../core/security/app_lock.dart';
import '../../core/theme/app_colors.dart';
import '../screens/lock/lock_screen.dart';

/// Makes [AppLock] available to every screen (Quick exit, Settings, the
/// safety plan) and rebuilds them when it changes.
class AppLockScope extends InheritedNotifier<AppLock> {
  const AppLockScope({super.key, required AppLock lock, required super.child})
    : super(notifier: lock);

  static AppLock? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.notifier;
}

/// Sits above every screen (MaterialApp.builder):
///  * locks when Looma goes to the background (after the chosen delay),
///  * shows the lock screen on top of everything while locked, except over
///    a Quick exit disguise (that would reveal Looma),
///  * with "Hide app preview" on, shows a blank cover whenever Looma is not
///    in front, so the app switcher shows nothing (iOS and web; Android
///    also uses the secure flag).
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.lock,
    required this.child,
    required this.onForgot,
  });

  final AppLock lock;
  final Widget child;

  /// "Forgot PIN": reset the lock, delete the safety plan, sign out.
  final Future<void> Function() onForgot;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  AppLifecycleState? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        widget.lock.onBackground();
      case AppLifecycleState.resumed:
        widget.lock.onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
    setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) {
    final lock = widget.lock;
    return AppLockScope(
      lock: lock,
      child: ListenableBuilder(
        listenable: lock,
        builder: (context, _) {
          final away = _state != null && _state != AppLifecycleState.resumed;
          final showLock = lock.locked && !lock.disguiseActive;
          return Stack(
            children: [
              // Hidden from screen readers and taps while locked.
              ExcludeSemantics(
                excluding: showLock,
                child: IgnorePointer(ignoring: showLock, child: widget.child),
              ),
              if (showLock)
                Positioned.fill(
                  child: LockScreen(lock: lock, onForgot: widget.onForgot),
                ),
              if (lock.hidePreview && away)
                Positioned.fill(
                  child: ColoredBox(
                    key: const ValueKey('privacy-cover'),
                    color: context.palette.background,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
