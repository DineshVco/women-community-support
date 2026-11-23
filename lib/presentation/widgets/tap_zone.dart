import 'package:flutter/widgets.dart';

/// The tappable areas of the cards on screen (poll answers, the counts
/// row), so a floating button can stay clear of them. A screen provides a
/// [TapZoneScope]; without one, [TapZone] does nothing.
class TapZoneRegistry {
  final Set<_TapZoneState> _zones = {};

  /// Where each zone is on screen right now.
  Iterable<Rect> get rects sync* {
    for (final zone in _zones) {
      final rect = zone.globalRect;
      if (rect != null) yield rect;
    }
  }

  /// True if [area] touches any zone. [dy] shifts the zones first (where
  /// they will be after a scroll that has not been laid out yet).
  bool overlaps(Rect area, {double dy = 0}) =>
      rects.any((r) => r.shift(Offset(0, dy)).overlaps(area));
}

class TapZoneScope extends InheritedWidget {
  const TapZoneScope({super.key, required this.registry, required super.child});

  final TapZoneRegistry registry;

  static TapZoneRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TapZoneScope>()?.registry;

  @override
  bool updateShouldNotify(TapZoneScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Marks [child] as a tappable area that floating buttons must not cover.
class TapZone extends StatefulWidget {
  const TapZone({super.key, required this.child});

  final Widget child;

  @override
  State<TapZone> createState() => _TapZoneState();
}

class _TapZoneState extends State<TapZone> {
  TapZoneRegistry? _registry;

  Rect? get globalRect {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = TapZoneScope.maybeOf(context);
    if (registry != _registry) {
      _registry?._zones.remove(this);
      _registry = registry?.._zones.add(this);
    }
  }

  @override
  void dispose() {
    _registry?._zones.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
