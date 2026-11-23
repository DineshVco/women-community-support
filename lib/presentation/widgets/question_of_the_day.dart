import 'package:flutter/material.dart';

import '../../core/constants/daily_questions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/help_lines.dart';
import 'looma_card.dart';

/// One compact card with today's gentle question (content/daily_questions
/// .json, one per day). Tapping it opens the compose screen with the
/// question as the title, so answers are anonymous like any post.
class QuestionOfTheDay extends StatelessWidget {
  const QuestionOfTheDay({super.key, required this.onAnswer});

  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return WithContent(
      builder: (context, library) {
        final question = DailyQuestions.forDate(
          library.dailyQuestions,
          DateTime.now(),
        );
        if (question == null) return const SizedBox.shrink();
        return _card(context, question);
      },
    );
  }

  Widget _card(BuildContext context, String question) {
    final palette = context.palette;
    final small = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: palette.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        LoomaCard.gap,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: LoomaCard(
        onTap: () => onAnswer(question),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Question of the day', style: small)),
                Text(
                  'Share your answer',
                  style: small.copyWith(color: palette.text),
                ),
                const SizedBox(width: 2),
                Icon(AppIcons.chevronRight, size: 14, color: palette.text),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading(19, palette.text, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
