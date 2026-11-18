import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../screens/decoy_screen.dart';

/// One tap hides the app behind a plain weather screen.
/// Shown as a small pill; the tap area is still the full 48 px.
/// (No haptic on purpose: a buzz could draw attention.)
class QuickExitButton extends StatelessWidget {
  const QuickExitButton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TextButton.icon(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const DecoyScreen()),
          (route) => false,
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: palette.text,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: StadiumBorder(side: BorderSide(color: palette.border)),
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontSize: 13, color: palette.text),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: const Icon(Icons.exit_to_app, size: 16),
      label: const Text('Quick exit'),
    );
  }
}
