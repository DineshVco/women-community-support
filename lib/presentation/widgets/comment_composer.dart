import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'press_scale.dart';

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
    this.hintText = 'Write a kind reply',
  });

  final TextEditingController controller;

  /// e.g. "Reply as Quiet Fox".
  final String hintText;

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
                      // Rounded pill field.
                      decoration: InputDecoration(
                        hintText: hintText,
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        enabledBorder: _pill(palette.border, 1),
                        border: _pill(palette.border, 1),
                        focusedBorder: _pill(palette.borderStrong, 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Black round send button.
                  PressScale(
                    enabled: !sending,
                    child: IconButton.filled(
                      onPressed: sending ? null : onSend,
                      tooltip: 'Send reply',
                      style: IconButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        disabledBackgroundColor: palette.border,
                        fixedSize: const Size(48, 48),
                      ),
                      icon:
                          sending
                              ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.textMuted,
                                ),
                              )
                              : const Icon(Icons.arrow_upward),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _pill(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
