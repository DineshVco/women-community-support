import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Keeps content in a readable column on tablets and web instead of
/// stretching it across the whole window.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Full width up to the limit (never shrink-wrapped and centred).
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
