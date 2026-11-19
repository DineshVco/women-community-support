/// Picks the gentle question of the day from content/daily_questions.json
/// (loaded into ContentLibrary.dailyQuestions). Everyone sees the same one,
/// and it changes at local midnight.
///
/// Every question must work as a post title (3 to 120 characters) and must
/// not invite anyone to share details that could identify them.
class DailyQuestions {
  DailyQuestions._();

  /// The question for [date]'s day of the year, or null with no questions.
  static String? forDate(List<String> questions, DateTime date) {
    if (questions.isEmpty) return null;
    // UTC dates avoid daylight-saving shifts changing the day count.
    final day =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(date.year, 1, 1)).inDays; // 0 on 1 January
    return questions[day % questions.length];
  }
}
