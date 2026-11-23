import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The alias of posts written by the Looma team (the starter posts). The
/// Firestore rules stop members from using it, so the badge can be trusted.
class LoomaTeam {
  LoomaTeam._();

  static const String alias = 'Looma Team';

  /// Shown on Home while starter posts are in the feed.
  static const String starterLine =
      'Starter posts to begin the conversation. Add yours.';

  static bool isTeam(String alias) => alias == LoomaTeam.alias;
}

/// A small "Looma Team" pill next to the team alias: black with white text
/// (in dark mode the colours swap, like the other tags).
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Looma Team',
        semanticsLabel: 'Written by the Looma team',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.onPrimary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// The alias (for the team: just the black badge), then e.g. " · 2h",
/// on one line.
class AliasLine extends StatelessWidget {
  const AliasLine({
    super.key,
    required this.alias,
    required this.text,
    required this.trailing,
    this.style,
  });

  /// The raw alias (decides the badge).
  final String alias;

  /// What to show for the alias ("You, as …" or the alias itself).
  final String text;

  /// Shown after the badge, e.g. " · 2h".
  final String trailing;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final team = LoomaTeam.isTeam(alias);
    // The team is named once, by the black badge (not "Looma Team" twice).
    final showText = !team || text != alias;
    return Row(
      children: [
        if (showText)
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        if (team) ...[
          if (showText) const SizedBox(width: 6),
          const TeamBadge(),
        ],
        Flexible(
          child: Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
