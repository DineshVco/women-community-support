import 'package:flutter/material.dart';

import '../../core/constants/daily_questions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// A soft green card with today's conversation starter.
/// "Share your answer" opens the compose screen with the question as title.
class QuestionOfTheDay extends StatelessWidget {
  const QuestionOfTheDay({super.key, required this.onAnswer});

  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final question = DailyQuestions.forDate(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION OF THE DAY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.primary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(question, style: theme.textTheme.titleMedium),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onAnswer(question),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Share your answer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
