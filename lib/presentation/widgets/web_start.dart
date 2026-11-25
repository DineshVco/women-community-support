import 'package:flutter/material.dart';

import '../../main.dart' show LoomaRoot, LoomaServices;

/// Web only: the first thing Flutter draws. It looks like the page's own
/// loading screen (index.html), which disappears at this first frame, so
/// she never sees a blank screen. Meanwhile Firebase, settings and content
/// load; then the app appears. If starting fails (no internet), it says so
/// and offers to try again.
class WebStart extends StatefulWidget {
  const WebStart({super.key, required this.start});

  /// Gets everything ready (called again by "Try again").
  final Future<LoomaServices> Function() start;

  /// The page's loading screen colours (the same as in index.html).
  static const Color lightBackground = Color(0xFFFEF7F2);
  static const Color darkBackground = Color(0xFF1C1614);
  static const Color lightText = Color(0xFF4A3B36);
  static const Color darkText = Color(0xFFF2E6DA);

  @override
  State<WebStart> createState() => _WebStartState();
}

class _WebStartState extends State<WebStart> {
  late Future<LoomaServices> _services = widget.start();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoomaServices>(
      future: _services,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services != null) return LoomaRoot(services: services);
        return _StartScreen(
          failed: snapshot.hasError,
          onRetry: () {
            final again = widget.start();
            setState(() {
              _services = again;
            });
          },
        );
      },
    );
  }
}

class _StartScreen extends StatelessWidget {
  const _StartScreen({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final text = dark ? WebStart.darkText : WebStart.lightText;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        key: const ValueKey('web-start'),
        color: dark ? WebStart.darkBackground : WebStart.lightBackground,
        child: Center(
          child: Semantics(
            label: failed ? null : 'Loading Looma',
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The same small picture the page showed (already loaded).
                ExcludeSemantics(
                  child: Image.network(
                    'icons/splash_cat.webp',
                    width: 96,
                    height: 96,
                    errorBuilder: (_, _, _) => const SizedBox(height: 96),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Looma',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 28,
                    color: text,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (failed) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Looma could not start. Check your internet connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 15,
                      color: text,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onRetry,
                    child: Semantics(
                      button: true,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Try again',
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: text,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
