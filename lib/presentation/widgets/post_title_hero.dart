import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// A post title that flies from the feed row into the discussion page.
///
/// The two ends use different text sizes, so the flight blends smoothly
/// between them. With reduce-motion on it is just plain text.
class PostTitleHero extends StatelessWidget {
  const PostTitleHero({
    super.key,
    required this.postId,
    required this.title,
    required this.style,
    this.maxLines,
  });

  final String postId;
  final String title;
  final TextStyle? style;
  final int? maxLines;

  static String tagFor(String postId) => 'post-title-$postId';

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );

    if (AppMotion.reduced(context)) return text;

    return Hero(
      tag: tagFor(postId),
      flightShuttleBuilder: _shuttle,
      child: Material(type: MaterialType.transparency, child: text),
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = _styleOf(fromHeroContext);
    final to = _styleOf(toHeroContext);

    // The route animation runs 0 → 1 on push and 1 → 0 on pop, so value 0
    // always means "feed row" and 1 always means "discussion page".
    final feedStyle = direction == HeroFlightDirection.push ? from : to;
    final pageStyle = direction == HeroFlightDirection.push ? to : from;
    final title = _titleOf(toHeroContext);

    return AnimatedBuilder(
      animation: animation,
      builder:
          (context, _) => Material(
            type: MaterialType.transparency,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  overflow: TextOverflow.clip,
                  style: TextStyle.lerp(feedStyle, pageStyle, animation.value),
                ),
              ),
            ),
          ),
    );
  }

  static Text _textOf(BuildContext heroContext) {
    final hero = heroContext.widget as Hero;
    return (hero.child as Material).child! as Text;
  }

  static TextStyle? _styleOf(BuildContext heroContext) =>
      _textOf(heroContext).style;

  static String _titleOf(BuildContext heroContext) =>
      _textOf(heroContext).data ?? '';
}
