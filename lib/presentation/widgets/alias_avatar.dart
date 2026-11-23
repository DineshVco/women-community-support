import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import 'team_badge.dart';

/// A small line-art avatar for an alias: a flower, leaf, moon, bird... in a
/// soft circle. Picked from the alias text only, so the same alias always
/// looks the same and nothing about the person is used. The Looma team
/// gets a black circle with a heart.
class AliasAvatar extends StatelessWidget {
  const AliasAvatar({super.key, required this.alias, this.size = 28});

  final String alias;
  final double size;

  static const List<IconData> drawings = [
    AppIcons.avatarFlower,
    AppIcons.avatarLeaf,
    AppIcons.avatarMoon,
    AppIcons.avatarSun,
    AppIcons.avatarBird,
    AppIcons.avatarButterfly,
    AppIcons.avatarCat,
    AppIcons.avatarFeather,
    AppIcons.avatarTulip,
    AppIcons.avatarLotus,
  ];

  /// A stable number for [alias] (the same on every phone and every run).
  static int indexFor(String alias) {
    var hash = 0;
    for (final unit in alias.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final team = LoomaTeam.isTeam(alias);
    final i = indexFor(alias);
    final tints = palette.softTints;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: team ? palette.primary : tints[i % tints.length],
          shape: BoxShape.circle,
        ),
        child: Icon(
          team ? AppIcons.heartFilled : drawings[i % drawings.length],
          size: size * 0.58,
          color: team ? palette.onPrimary : palette.text,
        ),
      ),
    );
  }
}
