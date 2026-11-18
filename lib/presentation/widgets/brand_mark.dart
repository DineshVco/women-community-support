import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Two overlapping rings: "circle". Used as the logo instead of a stock icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget ring(Color color) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: size * 0.12),
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(
        width: size * 1.6,
        height: size,
        child: Stack(
          children: [
            Positioned(left: 0, child: ring(palette.primary)),
            Positioned(right: 0, child: ring(palette.accent)),
          ],
        ),
      ),
    );
  }
}

/// Logo + name, used at the top of screens.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'HerCircle',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }
}
