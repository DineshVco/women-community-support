import 'package:flutter/widgets.dart';

/// Short-lived pop-ups drawn above every screen (the "Posted" pill, the
/// first-post hearts). Quick exit removes them all at once, so nothing
/// from Looma can show on top of a disguise or linger after coming back.
class TransientOverlays {
  TransientOverlays._();

  static final Set<OverlayEntry> _entries = {};

  static void insert(OverlayState overlay, OverlayEntry entry) {
    _entries.add(entry);
    overlay.insert(entry);
  }

  /// Safe to call more than once.
  static void remove(OverlayEntry entry) {
    _entries.remove(entry);
    if (entry.mounted) entry.remove();
  }

  static void removeAll() {
    for (final entry in List.of(_entries)) {
      remove(entry);
    }
  }
}
