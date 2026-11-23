import 'package:flutter/services.dart';

/// Loads Looma's real fonts into the test, so text measures as on a phone.
/// (By default tests draw every letter as a full square, which makes text
/// far wider and taller than it really is.)
Future<void> loadRealFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await load('Newsreader', [
    'assets/fonts/Newsreader-Regular.ttf',
    'assets/fonts/Newsreader-SemiBold.ttf',
  ]);
  await load('Figtree', [
    'assets/fonts/Figtree-Regular.ttf',
    'assets/fonts/Figtree-Medium.ttf',
    'assets/fonts/Figtree-SemiBold.ttf',
    'assets/fonts/Figtree-Bold.ttf',
  ]);
  // The greeting's handwriting, as google_fonts names it (Caveat, 600).
  await load('Caveat_600', ['assets/google_fonts/Caveat-SemiBold.ttf']);
}
