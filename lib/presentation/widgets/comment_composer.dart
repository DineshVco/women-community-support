import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Reply box pinned to the bottom of the discussion screen.
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.sending,
    this.replyingToAlias,
    this.onCancelReply,
    this.focusNode,
  });

  final TextEditingController controller;

  /// Lets the screen move the cursor here when someone taps "Reply".
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool sending;
  final String? replyingToAlias;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyingToAlias != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $replyingToAlias',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      onPressed: onCancelReply,
                      tooltip: 'Cancel reply',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write a kind reply',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    onPressed: sending ? null : onSend,
                    tooltip: 'Send reply',
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
