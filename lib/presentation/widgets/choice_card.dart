import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/haptics.dart';
import 'press_scale.dart';
import '../../core/theme/app_icons.dart';

/// An option card. Selected: 1.8 px black border and a filled black circle
/// with a white tick on the right. Not selected: 1 px grey border and an
/// empty circle.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.of(context, AppMotion.fast);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressScale(
        child: Material(
          // Selected: a faint blush wash behind the black border.
          color: selected ? palette.blushTint : palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(
              color: selected ? palette.borderStrong : palette.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () {
              if (!selected) AppHaptics.selection();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: duration,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? palette.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? palette.primary : palette.border,
                        width: 1.5,
                      ),
                    ),
                    child:
                        selected
                            ? Icon(
                              AppIcons.check,
                              size: 16,
                              color: palette.onPrimary,
                            )
                            : null,
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
