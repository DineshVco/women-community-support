/// One gentle conversation starter per day, shown at the top of the feed.
///
/// Every question must work as a post title (3–120 characters) and must not
/// invite anyone to share details that could identify them.
class DailyQuestions {
  DailyQuestions._();

  static const List<String> all = [
    'What is one small thing that made you feel safe this week?',
    'What money advice would you give your younger self?',
    'How do you look after your mental health on hard days?',
    'What helped you speak up at work for the first time?',
    'Which study habit actually worked for you?',
    'What is a boundary you set this year that you are proud of?',
    'How do you deal with unwanted comments in public?',
    'What is one health check every woman should know about?',
    'How did you prepare for your first job interview?',
    'Who is a woman that inspired you, and why?',
    'What do you do to feel safe when travelling alone?',
    'How do you rest when you feel burnt out?',
    'What do you wish you had learned sooner about your body?',
    'How did you ask for a raise or a promotion?',
    'What helps you stay focused during exam season?',
    'What does a good friend do when you are struggling?',
    'How do you handle the guilt of saying no?',
    'What is one skill you taught yourself online?',
    'How do you balance family expectations with your own goals?',
    'What would make your campus or workplace safer for women?',
    'What is a kind thing a stranger once did for you?',
    'How do you calm yourself before something stressful?',
    'What helped you cope with period pain or hormone changes?',
    'What would you tell someone starting their first job?',
    'How do you know when a relationship is not healthy?',
    'What is one scholarship or resource more people should know about?',
    'How do you make time for yourself in a busy week?',
    'What is a career myth you used to believe?',
    'What do you wish people understood about asking for help?',
    'What is one small win you want to celebrate today?',
  ];

  /// The question for [date]'s day of the year. Everyone sees the same one,
  /// and it changes at local midnight.
  static String forDate(DateTime date) {
    // UTC dates avoid daylight-saving shifts changing the day count.
    final day =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(date.year, 1, 1)).inDays; // 0 on 1 January
    return all[day % all.length];
  }
}
