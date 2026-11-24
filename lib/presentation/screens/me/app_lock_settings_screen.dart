import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/security/app_lock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/app_lock_gate.dart';
import '../../widgets/content_width.dart';
import '../../widgets/ios.dart';
import '../../widgets/looma_button.dart';
import '../lock/lock_screen.dart';
import '../../../core/theme/app_icons.dart';
import '../../widgets/quick_exit_button.dart';

/// Asks for the PIN (or fingerprint / face) before something sensitive:
/// opening the safety plan, changing or turning off the PIN.
Future<bool> confirmWithPin(BuildContext context, AppLock lock) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder:
          (routeContext) => Scaffold(
            appBar: loomaNavBar(context),
            body: LockScreen(
              lock: lock,
              title: 'Enter your PIN to continue',
              onUnlocked: () => Navigator.of(routeContext).pop(true),
            ),
          ),
    ),
  );
  return ok ?? false;
}

/// Me > Privacy centre > App lock.
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  Future<bool>? _biometricsAvailable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _biometricsAvailable ??=
        AppLockScope.maybeOf(context)?.biometricsAvailable() ??
        Future.value(false);
  }

  Future<void> _turnOn(AppLock lock) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SetPinScreen(onSet: lock.setPin)),
    );
  }

  Future<void> _changePin(AppLock lock) async {
    if (!await confirmWithPin(context, lock) || !mounted) return;
    await _turnOn(lock);
  }

  Future<void> _turnOff(AppLock lock) async {
    if (!await confirmWithPin(context, lock) || !mounted) return;
    await lock.disable();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App lock is off')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lock = AppLockScope.maybeOf(context);
    if (lock == null) return const Scaffold(body: SizedBox.shrink());
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: loomaNavBar(
        context,
        title: 'App lock',
        trailing: const QuickExitButton(),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            children: [
              if (!lock.enabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: Text(
                    'Ask for a 6-digit PIN whenever Looma is opened again. '
                    'Only a scrambled version of your PIN is kept, on this '
                    'phone.',
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: LoomaButton.primary(
                    label: 'Turn on App lock',
                    showArrow: false,
                    onPressed: () => _turnOn(lock),
                  ),
                ),
              ] else ...[
                GroupedSection(
                  footer:
                      'Asks for your 6-digit PIN whenever Looma is opened '
                      'again. Only a scrambled version of your PIN is kept, '
                      'on this phone.',
                  children: [
                    GroupedSwitchRow(
                      icon: AppIcons.lock,
                      title: 'App lock',
                      value: true,
                      onChanged: (_) => _turnOff(lock),
                    ),
                    GroupedRow(
                      icon: AppIcons.passcode,
                      title: 'Change PIN',
                      onTap: () => _changePin(lock),
                    ),
                    FutureBuilder<bool>(
                      future: _biometricsAvailable,
                      builder: (context, snapshot) {
                        if (snapshot.data != true) {
                          return const SizedBox.shrink();
                        }
                        return GroupedSwitchRow(
                          icon: AppIcons.faceId,
                          title: 'Unlock with fingerprint or face',
                          value: lock.biometrics,
                          onChanged: lock.setBiometrics,
                        );
                      },
                    ),
                  ],
                ),
                GroupedSection(
                  header: 'Lock after leaving Looma',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: LoomaSegmented<LockAfter>(
                        value: lock.lockAfter,
                        options: {for (final a in LockAfter.values) a: a.label},
                        onChanged: lock.setLockAfter,
                      ),
                    ),
                  ],
                ),
                GroupedSection(
                  footer:
                      android
                          ? 'Shows a blank screen in the app switcher. This '
                              'also blocks screenshots in Looma while it is on.'
                          : 'Shows a blank screen in the app switcher.',
                  children: [
                    GroupedSwitchRow(
                      icon: AppIcons.eyeSlash,
                      title: 'Hide Looma in recent apps',
                      value: lock.hidePreview,
                      onChanged: lock.setHidePreview,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    'Forgot your PIN? Tap "Forgot PIN" on the lock screen. '
                    'You will be signed out and the safety plan on this phone '
                    'is deleted. Your posts and chat profile stay on the '
                    'server.',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
