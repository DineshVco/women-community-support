import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/security/app_lock.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/ios.dart';

/// Six dots and a number pad. Used by the lock screen and "Set PIN".
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.filled,
    required this.onDigit,
    required this.onBackspace,
    this.extraKey,
    this.enabled = true,
    this.error = false,
  });

  /// How many digits are typed (0-6).
  final int filled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Bottom-left key, e.g. fingerprint.
  final Widget? extraKey;
  final bool enabled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.of(context, AppMotion.fast);

    Widget digitKey(String d) => _Key(
      label: d,
      semantics: d,
      onTap:
          enabled
              ? () {
                AppHaptics.selection();
                onDigit(d);
              }
              : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$filled of ${PinHasher.pinLength} digits entered',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < PinHasher.pinLength; i++)
                AnimatedContainer(
                  duration: duration,
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        i < filled
                            ? (error ? palette.danger : palette.text)
                            : Colors.transparent,
                    border: Border.all(
                      color: error ? palette.danger : palette.text,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) digitKey(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 88, height: 80, child: extraKey),
            digitKey('0'),
            _Key(
              icon: Icons.backspace_outlined,
              semantics: 'Delete',
              onTap:
                  enabled && filled > 0
                      ? () {
                        AppHaptics.selection();
                        onBackspace();
                      }
                      : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.semantics, this.onTap});

  final String? label;
  final IconData? icon;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 88,
      height: 80,
      child: Center(
        child: Semantics(
          button: true,
          label: semantics,
          excludeSemantics: true,
          child: Material(
            color: label == null ? Colors.transparent : palette.softFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Center(
                  child:
                      label != null
                          ? Text(
                            label!,
                            style: TextStyle(
                              fontSize: 28,
                              color: palette.text,
                              fontWeight: FontWeight.w400,
                            ),
                          )
                          : Icon(icon, color: palette.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lock screen: wordmark, PIN dots, number pad. It says nothing about
/// what is inside the app.
///
/// [onForgot] null hides "Forgot PIN" (e.g. when only confirming the PIN
/// before opening the safety plan).
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.lock,
    this.onForgot,
    this.onUnlocked,
    this.title = 'Enter your PIN',
    this.autoBiometrics = true,
  });

  final AppLock lock;
  final Future<void> Function()? onForgot;
  final VoidCallback? onUnlocked;
  final String title;
  final bool autoBiometrics;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _checking = false;
  bool _error = false;
  bool _confirmForgot = false;
  bool _forgetting = false;
  Timer? _ticker;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    _startTickerIfWaiting();
    if (widget.autoBiometrics && widget.lock.biometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometrics());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    _pin = '';
    super.dispose();
  }

  void _startTickerIfWaiting() {
    _ticker?.cancel();
    if (widget.lock.waitLeft == Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (widget.lock.waitLeft == Duration.zero) timer.cancel();
    });
  }

  Future<void> _biometrics() async {
    if (!mounted) return;
    final ok = await widget.lock.unlockWithBiometrics();
    if (ok && mounted) {
      AppHaptics.medium();
      widget.onUnlocked?.call();
    }
  }

  Future<void> _digit(String d) async {
    if (_checking || _pin.length >= PinHasher.pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length < PinHasher.pinLength) return;

    setState(() => _checking = true);
    final result = await widget.lock.verify(_pin);
    if (!mounted) return;
    if (result == PinResult.ok) {
      AppHaptics.medium();
      _pin = '';
      _checking = false;
      widget.onUnlocked?.call();
      if (mounted) setState(() {});
      return;
    }
    AppHaptics.warning();
    setState(() {
      _pin = '';
      _checking = false;
      _error = true;
    });
    if (!AppMotion.reduced(context)) _shake.forward(from: 0);
    _startTickerIfWaiting();
  }

  Future<void> _forget() async {
    final onForgot = widget.onForgot;
    if (onForgot == null) return;
    setState(() => _forgetting = true);
    await onForgot();
    if (mounted) setState(() => _forgetting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final wait = widget.lock.waitLeft;
    final waiting = wait > Duration.zero;

    final String message;
    if (waiting) {
      message = 'Too many tries. Try again in ${wait.inSeconds + 1} s.';
    } else if (_error) {
      message = 'That PIN is not right.';
    } else {
      message = widget.title;
    }

    final Widget body =
        _confirmForgot
            ? _ForgotPanel(
              busy: _forgetting,
              onConfirm: _forget,
              onCancel: () => setState(() => _confirmForgot = false),
            )
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color:
                        _error || waiting
                            ? palette.danger
                            : palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AnimatedBuilder(
                  animation: _shake,
                  builder:
                      (context, child) => Transform.translate(
                        offset: Offset(
                          math.sin(_shake.value * math.pi * 4) *
                              10 *
                              (1 - _shake.value),
                          0,
                        ),
                        child: child,
                      ),
                  child: PinPad(
                    filled: _pin.length,
                    error: _error,
                    enabled: !_checking && !waiting,
                    onDigit: _digit,
                    onBackspace:
                        () => setState(
                          () => _pin = _pin.substring(0, _pin.length - 1),
                        ),
                    extraKey:
                        widget.lock.biometrics
                            ? Center(
                              child: IconButton(
                                iconSize: 30,
                                onPressed: waiting ? null : _biometrics,
                                icon: const Icon(Icons.fingerprint),
                                tooltip: null,
                              ),
                            )
                            : null,
                  ),
                ),
                if (widget.onForgot != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => setState(() => _confirmForgot = true),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.textSecondary,
                    ),
                    child: const Text('Forgot PIN'),
                  ),
                ],
              ],
            );

    return Material(
      color: palette.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Wordmark(),
                  const SizedBox(height: AppSpacing.xxl),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPanel extends StatelessWidget {
  const _ForgotPanel({
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
  });

  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  static const String text =
      'You will be signed out and App lock will be turned off. Your safety '
      'plan on this phone will be deleted, because only your PIN protected '
      'it.\n\nYour posts, replies and chat profile stay on the server. Sign '
      'in again with your email or Google to get back to them.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Forgot your PIN?',
          style: AppTypography.heading(24, palette.text),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(text, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        LoomaButton.primary(
          label: 'Sign out and reset',
          showArrow: false,
          loading: busy,
          onPressed: onConfirm,
        ),
        const SizedBox(height: AppSpacing.md),
        LoomaButton.outline(label: 'Cancel', onPressed: busy ? null : onCancel),
      ],
    );
  }
}

/// Choose a PIN, then type it again.
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key, required this.onSet});

  /// Called with the confirmed PIN.
  final Future<void> Function(String pin) onSet;

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  bool _mismatch = false;
  bool _saving = false;

  @override
  void dispose() {
    _first = '';
    _pin = '';
    super.dispose();
  }

  Future<void> _digit(String d) async {
    if (_saving || _pin.length >= PinHasher.pinLength) return;
    setState(() {
      _mismatch = false;
      _pin += d;
    });
    if (_pin.length < PinHasher.pinLength) return;

    if (!_confirming) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }
    if (_pin != _first) {
      AppHaptics.warning();
      setState(() {
        _pin = '';
        _first = '';
        _confirming = false;
        _mismatch = true;
      });
      return;
    }
    setState(() => _saving = true);
    await widget.onSet(_pin);
    if (!mounted) return;
    AppHaptics.medium();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final String title;
    if (_mismatch) {
      title = 'Those did not match. Choose a 6-digit PIN again.';
    } else if (_confirming) {
      title = 'Type the same PIN again';
    } else {
      title = 'Choose a 6-digit PIN';
    }

    return Scaffold(
      appBar: loomaNavBar(context, title: 'App lock'),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _mismatch ? palette.danger : palette.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pick something others will not guess. Not your birthday.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PinPad(
                  filled: _pin.length,
                  error: _mismatch,
                  enabled: !_saving,
                  onDigit: _digit,
                  onBackspace:
                      () => setState(
                        () => _pin = _pin.substring(0, _pin.length - 1),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
