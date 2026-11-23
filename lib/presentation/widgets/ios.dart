import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/haptics.dart';
import 'looma_card.dart';

// iOS-style building blocks, used on Android too, in Looma's black and
// white style (Newsreader headings, system font for body text).

/// Translucent bar colour: content shows through, blurred.
Color barColor(BuildContext context) =>
    context.palette.background.withValues(alpha: 0.82);

/// The 1 px line under top bars and above the tab bar.
Border hairline(BuildContext context, {bool top = false}) {
  final side = BorderSide(color: context.palette.border, width: 0.5);
  return top ? Border(top: side) : Border(bottom: side);
}

/// A tab screen with an iOS large title that shrinks into the bar while
/// scrolling. The bar is translucent and blurred; content scrolls under it.
/// [onRefresh] adds the iOS pull-to-refresh spinner.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.leading,
    this.onRefresh,
    this.floatingActionButton,
    this.controller,
    this.onUserScroll,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Widget? leading;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final ScrollController? controller;
  final bool Function(UserScrollNotification)? onUserScroll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(
            title,
            style: AppTypography.heading(34, palette.text, height: 1.1),
          ),
          middle: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          alwaysShowMiddle: false,
          leading: leading,
          trailing: trailing,
          backgroundColor: barColor(context),
          border: hairline(context),
          // Several tab screens live in one route: no hero between them.
          transitionBetweenRoutes: false,
          automaticallyImplyLeading: false,
        ),
        if (onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
        // Room for the tab bar (content scrolls under it).
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
        ),
      ],
    );
    if (onUserScroll != null) {
      scroll = NotificationListener<UserScrollNotification>(
        onNotification: onUserScroll,
        child: scroll,
      );
    }

    // The tab bar is translucent and drawn over this screen, so lift the
    // floating button above it (Flutter only allows for the phone's edge).
    final media = MediaQuery.of(context);
    final barHeight = (media.padding.bottom - media.viewPadding.bottom).clamp(
      0.0,
      double.infinity,
    );

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton:
          floatingActionButton == null
              ? null
              : Padding(
                padding: EdgeInsets.only(bottom: barHeight),
                child: floatingActionButton,
              ),
      body: scroll,
    );
  }
}

/// iOS navigation bar for pushed screens: centred title, back chevron,
/// translucent and blurred, with a hairline.
CupertinoNavigationBar loomaNavBar(
  BuildContext context, {
  String? title,
  Widget? trailing,
  Widget? leading,
}) {
  final palette = context.palette;
  return CupertinoNavigationBar(
    middle:
        title == null
            ? null
            : Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
    leading: leading,
    trailing: trailing,
    backgroundColor: barColor(context),
    border: hairline(context),
    transitionBetweenRoutes: false,
  );
}

/// Several trailing buttons side by side in a navigation bar.
class NavBarActions extends StatelessWidget {
  const NavBarActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

// ───────────────────────── Grouped lists ─────────────────────────

/// A grouped list in the Looma card style: a small grey header, then one
/// card (20 px corners, 1 px warm border, soft shadow in light mode) with
/// hairline separators that start after the icons.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  /// Where a separator starts: after the icon circle, or at the text.
  static double _inset(Widget child) =>
      child is GroupedRow && child.icon != null ? 58 : 16;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final small = TextStyle(
      fontSize: 13,
      color: palette.textSecondary,
      letterSpacing: 0.3,
    );
    final radius = BorderRadius.circular(AppRadius.card);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Semantics(
                header: true,
                child: Text(
                  header!.toUpperCase(),
                  style: small.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: radius,
              border: Border.all(color: palette.border),
              boxShadow: LoomaCard.shadowFor(Theme.of(context).brightness),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.only(left: _inset(children[i])),
                        child: Container(height: 0.5, color: palette.border),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!, style: small),
            ),
        ],
      ),
    );
  }
}

/// A small "Coming soon" tag for rows that are not ready yet. The row stays
/// readable (not greyed out).
class ComingSoonTag extends StatelessWidget {
  const ComingSoonTag({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.categoryFill('personal_safety'),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Coming soon',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      ),
    );
  }
}

/// One row in a [GroupedSection]: outlined icon, title, optional subtitle,
/// and a chevron (when tappable) or a custom [trailing].
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
    this.tint,
  });

  final String title;
  final IconData? icon;

  /// The soft circle behind the icon (defaults to a warm grey).
  final Color? tint;
  final String? subtitle;

  /// Shown in grey before the chevron, e.g. "On" or a city.
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color =
        !enabled
            ? palette.textMuted
            : destructive
            ? CupertinoColors.destructiveRed.resolveFrom(context)
            : palette.text;

    // With large text there is no room beside the title: the value goes
    // under it instead (no overflow at any text size).
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    final valueBeside = value != null && !largeText;
    final lines = [
      if (subtitle != null) subtitle!,
      if (value != null && !valueBeside) value!,
    ];

    return Semantics(
      button: onTap != null,
      enabled: enabled,
      child: CupertinoListTile.notched(
        // Room above and below two-line subtitles and large text.
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
        backgroundColor: palette.surface,
        backgroundColorActivated: palette.softFill,
        leadingSize: 32,
        leading:
            icon == null
                ? null
                : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tint ?? palette.softFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
        title: Text(
          title,
          maxLines: 3,
          // Same weight with or without a subtitle (iOS lists).
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
        subtitle:
            lines.isEmpty
                ? null
                : Text(
                  lines.join('\n'),
                  maxLines: 4,
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
        additionalInfo:
            !valueBeside
                ? null
                : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ),
        trailing:
            trailing ??
            (onTap != null && enabled && !destructive
                ? const CupertinoListTileChevron()
                : null),
        onTap:
            enabled && onTap != null
                ? () {
                  AppHaptics.light();
                  onTap!();
                }
                : null,
      ),
    );
  }
}

/// A switch row: iOS switch, selection haptic.
class GroupedSwitchRow extends StatelessWidget {
  const GroupedSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;

  /// Null shows the switch greyed out.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      enabled: true,
      trailing: LoomaSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// CupertinoSwitch in Looma colours (black on, white in dark mode).
class LoomaSwitch extends StatelessWidget {
  const LoomaSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoSwitch(
      value: value,
      activeTrackColor: palette.primary,
      // Dark mode: the "on" track is near-white, so the thumb turns dark;
      // when off it stays light so it never disappears into the track.
      thumbColor:
          Theme.of(context).brightness == Brightness.dark && value
              ? palette.onPrimary
              : CupertinoColors.white,
      onChanged:
          onChanged == null
              ? null
              : (v) {
                AppHaptics.selection();
                onChanged!(v);
              },
    );
  }
}

/// iOS sliding segmented control in Looma colours.
class LoomaSegmented<T extends Object> extends StatelessWidget {
  const LoomaSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: palette.softFill,
        // The selected segment is the raised one (lighter in dark mode).
        thumbColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4A4845)
                : palette.surface,
        children: {
          for (final entry in options.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      entry.key == value ? FontWeight.w600 : FontWeight.w400,
                  color: palette.text,
                ),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v == null || v == value) return;
          AppHaptics.selection();
          onChanged(v);
        },
      ),
    );
  }
}

/// A clean filter pill (no Material chip, no checkmark).
class Pill extends StatelessWidget {
  const Pill({
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
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 250)),
          curve: AppMotion.spring,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.primary : palette.softFill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? palette.onPrimary : palette.text,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Bottom sheets ─────────────────────────

/// An iOS-style bottom sheet: rounded 20 corners, a small grabber, drag
/// down to dismiss, and a blurred backdrop.
Future<T?> showLoomaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final reduced = AppMotion.reduced(context);
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: true,
    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder:
        (_) => _LoomaSheet(reducedMotion: reduced, child: builder(context)),
  );
}

class _LoomaSheet extends StatefulWidget {
  const _LoomaSheet({required this.child, required this.reducedMotion});

  final Widget child;
  final bool reducedMotion;

  @override
  State<_LoomaSheet> createState() => _LoomaSheetState();
}

class _LoomaSheetState extends State<_LoomaSheet>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  late final AnimationController _settle;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(
      () => setState(
        () => _drag = _from * (1 - AppMotion.spring.transform(_settle.value)),
      ),
    );
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    setState(() => _drag = (_drag + d.delta.dy).clamp(0, double.infinity));
  }

  void _end(DragEndDetails d) {
    final height = context.size?.height ?? 400;
    if (_drag > height * 0.3 || d.velocity.pixelsPerSecond.dy > 700) {
      Navigator.of(context).pop();
      return;
    }
    // Not far enough: spring back up.
    _from = _drag;
    if (widget.reducedMotion) {
      setState(() => _drag = 0);
    } else {
      _settle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Transform.translate(
      offset: Offset(0, _drag),
      child: GestureDetector(
        onVerticalDragUpdate: _update,
        onVerticalDragEnd: _end,
        child: Material(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Grabber.
                Container(
                  key: const ValueKey('sheet-grabber'),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
