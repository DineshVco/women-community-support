import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../../core/theme/app_icons.dart';

/// A poll: the options as buttons until she votes, then rounded bars with
/// percentages. Results are shown only after she votes. One vote, final.
///
/// Pure (no Firebase), so it can be tested; [LivePoll] wires it up.
class PollView extends StatefulWidget {
  const PollView({
    super.key,
    required this.options,
    required this.counts,
    required this.voted,
    required this.onVote,
  });

  final List<String> options;
  final List<int> counts;

  /// Null while we do not know yet.
  final bool? voted;

  /// Saves the vote. Throws if it could not be saved.
  final Future<void> Function(int option) onVote;

  static const String hint = 'Tap an answer to vote. Results show after.';

  @override
  State<PollView> createState() => _PollViewState();
}

class _PollViewState extends State<PollView> {
  /// The answer she picked on this screen (shown with a tick).
  int? _picked;
  bool _sending = false;

  Future<void> _vote(int option) async {
    if (_sending) return;
    AppHaptics.selection();
    setState(() {
      _sending = true;
      _picked = option;
    });
    try {
      await widget.onVote(option);
    } catch (_) {
      if (!mounted) return;
      setState(() => _picked = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your vote. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final showResults = widget.voted == true;
    final total = widget.counts.fold<int>(0, (a, b) => a + b);
    final small = TextStyle(fontSize: 13, color: palette.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.options.length; i++) ...[
          if (showResults)
            _ResultBar(
              label: widget.options[i],
              share:
                  total == 0 || i >= widget.counts.length
                      ? 0
                      : widget.counts[i] / total,
              picked: _picked == i,
            )
          else
            _OptionButton(
              label: widget.options[i],
              enabled: widget.voted == false && !_sending,
              busy: _sending && _picked == i,
              onTap: () => _vote(i),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          showResults
              ? (total == 1 ? '1 vote' : '$total votes')
              : PollView.hint,
          style: small,
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      container: true,
      button: true,
      label: 'Vote: $label',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: StadiumBorder(side: BorderSide(color: palette.borderStrong)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 15, color: palette.text),
                    ),
                  ),
                  if (busy) const CupertinoActivityIndicator(radius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({
    required this.label,
    required this.share,
    required this.picked,
  });

  final String label;

  /// 0 to 1.
  final double share;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final percent = '${(share * 100).round()}%';
    final textStyle = TextStyle(
      fontSize: 15,
      color: palette.text,
      fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
    );

    // Its own item for screen readers: "Sometimes, 40%, your vote".
    return Semantics(
      container: true,
      label: '$label, $percent${picked ? ', your vote' : ''}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: ShapeDecoration(
          color: palette.softFill,
          shape: const StadiumBorder(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // The bar grows in; no motion when "Reduce motion" is on.
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share),
                duration: AppMotion.of(context, AppMotion.slow),
                curve: AppMotion.enter,
                builder:
                    (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: palette.blush.withValues(alpha: 0.55),
                      ),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 11,
              ),
              child: Row(
                children: [
                  if (picked) ...[
                    Icon(AppIcons.check, size: 16, color: palette.text),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: Text(label, style: textStyle)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(percent, style: textStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [PollView] for a poll post, with her vote state from Firestore.
class LivePoll extends StatefulWidget {
  const LivePoll({super.key, required this.post});

  final Post post;

  @override
  State<LivePoll> createState() => _LivePollState();
}

class _LivePollState extends State<LivePoll> {
  late final PostRepository _repo = context.read<PostRepository>();
  late final Stream<bool> _voted = _repo.watchVoted(widget.post.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _voted,
      builder:
          (context, snapshot) => PollView(
            options: widget.post.options,
            counts: widget.post.voteCounts,
            voted: snapshot.data,
            onVote: (option) => _repo.vote(widget.post.id, option),
          ),
    );
  }
}
