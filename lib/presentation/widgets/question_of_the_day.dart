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
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: LoomaCard(
        onTap: () => onAnswer(question),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: palette.tabPill,
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.sparkle, size: 18, color: palette.text),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Question of the day', style: small),
                      ),
                      Text(
                        'Share your answer',
                        style: small.copyWith(color: palette.text),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        AppIcons.chevronRight,
                        size: 14,
                        color: palette.text,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading(
                      17,
                      palette.text,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
