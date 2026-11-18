import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'transient_overlays.dart';
import 'floating_illustration.dart';

/// A short "Posted" pill that drops in at the top of the screen, stays for a
/// moment and fades away. It never blocks taps.
void showPostedConfirmation(BuildContext context, {required String alias}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final message = 'Posted as $alias';

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (_) => _PostedConfirmation(
          message: message,
          onDone: () => TransientOverlays.remove(entry),
        ),
  );
  TransientOverlays.insert(overlay, entry);

  // Screen readers hear it even though it is not focusable.
  SemanticsService.announce(message, Directionality.of(context));
}

class _PostedConfirmation extends StatefulWidget {
  const _PostedConfirmation({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_PostedConfirmation> createState() => _PostedConfirmationState();
}

class _PostedConfirmationState extends State<_PostedConfirmation>
    with SingleTickerProviderStateMixin {
  static const Duration _hold = Duration(milliseconds: 1600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    reverseDuration: AppMotion.fast,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
    reverseCurve: AppMotion.exit,
  );
  late final Animation<double> _spring = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.springPop,
    reverseCurve: AppMotion.exit,
  );

  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (AppMotion.reduced(context)) {
      _controller.duration = Duration.zero;
      _controller.reverseDuration = Duration.zero;
    }
    _controller.forward();
    _timer = Timer(_hold, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final top = MediaQuery.paddingOf(context).top + AppSpacing.lg;

    return Positioned(
      top: top,
      left: AppSpacing.screenHorizontal,
      right: AppSpacing.screenHorizontal,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(_spring),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(_spring),
                child: Material(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The heart cat says thank you. White circle: the
                        // drawing has dark lines and the pill is dark.
                        Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            LoomaCats.heart,
                            cacheWidth: 120,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: palette.onPrimary,
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
        ),
      ),
    );
  }
}
