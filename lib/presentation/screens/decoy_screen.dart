import 'package:flutter/material.dart';

import 'auth_gate.dart';

/// Shown by "Quick exit". It looks like an ordinary weather screen so that
/// anyone glancing at the phone does not see HerCircle.
/// Long-press anywhere to go back to the app.
///
/// The colours are deliberately hard-coded: this screen must NOT look like
/// part of HerCircle.
class DecoyScreen extends StatelessWidget {
  const DecoyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AuthGate()),
          (route) => false,
        );
      },
      child: const Scaffold(
        backgroundColor: Color(0xFFDCEBF7),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kuala Lumpur',
                  style: TextStyle(fontSize: 24, color: Color(0xFF1E3A52)),
                ),
                SizedBox(height: 8),
                Text(
                  '31°',
                  style: TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w200,
                    color: Color(0xFF1E3A52),
                  ),
                ),
                Text(
                  'Partly cloudy',
                  style: TextStyle(fontSize: 18, color: Color(0xFF3F5E78)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
