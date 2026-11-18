/// Very small client-side checks that run before a post or reply is sent.
///
/// This is a first line of defence only. Real moderation is the report
/// button + moderator queue. Extend the word lists as needed.
class ContentFilter {
  ContentFilter._();

  static final RegExp _blocked = RegExp(
    r'\b(fuck|fucking|bitch|cunt|pukimak|puki|sial)\b',
    caseSensitive: false,
  );

  static final RegExp _distress = RegExp(
    r"(suicid|kill myself|end my life|want to die|self[- ]?harm|bunuh diri)",
    caseSensitive: false,
  );

  /// True if the text contains language we do not allow.
  static bool isDisrespectful(String text) => _blocked.hasMatch(text);

  /// True if the text suggests the writer may be in distress.
  static bool suggestsDistress(String text) => _distress.hasMatch(text);
}
