import 'package:flutter/material.dart';

import '../screens/decoy_screen.dart';

/// One tap hides the app behind a plain weather screen.
class QuickExitButton extends StatelessWidget {
  const QuickExitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const DecoyScreen()),
          (route) => false,
        );
      },
      icon: const Icon(Icons.exit_to_app, size: 20),
      label: const Text('Quick exit'),
    );
  }
}
