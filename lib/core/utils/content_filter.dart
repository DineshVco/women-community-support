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

/// Finds contact details: links, web addresses, emails, @handles and phone
/// numbers. Looma Connect never allows these (safety: no moving a chat
/// somewhere else, no sharing ways to find someone).
///
/// firestore.rules has the same patterns (`noContact`). Change both together.
class ContactFilter {
  ContactFilter._();

  static final List<RegExp> _patterns = [
    // http://… https://… www.…
    RegExp(r'(https?://|www\.)', caseSensitive: false),
    // something.com, name.my, link.io …
    RegExp(
      r'[a-z0-9-]+\.(com|net|org|my|io|me|co|app|ly|gg|xyz|info|biz)(?![a-z])',
      caseSensitive: false,
    ),
    // name@mail.com and @handle
    RegExp(r'@[A-Za-z0-9_]'),
    // 9 or more digits, allowing spaces, dashes, dots, brackets and +
    RegExp(r'([0-9][ ()+.\-]*){9,}'),
  ];

  static bool containsContactDetails(String text) =>
      _patterns.any((p) => p.hasMatch(text));

  /// Shown when a message, bio or alias is refused.
  static const String kindMessage =
      'For your safety, links and contact details are not allowed here.';
}

/// Checks for the chat alias and bio. Each returns null when the text is
/// fine, or a short, kind explanation of what to change.
class ChatProfileChecks {
  ChatProfileChecks._();

  static final RegExp _aliasChars = RegExp(r'^[A-Za-z0-9 _.\-]+$');

  /// "Siti Aminah", "Quiet Fern": two or more capitalised words. Looks like a
  /// real name, or like a post alias (which must never be reused for chat).
  static final RegExp _fullName = RegExp(r'^[A-Z][a-z]+( +[A-Z][a-z]+)+$');

  static String? alias(String raw, {String? email, String? displayName}) {
    final alias = raw.trim();
    if (alias.length < 3) return 'Use at least 3 characters.';
    if (alias.length > 20) return 'Use 20 characters or fewer.';
    if (!_aliasChars.hasMatch(alias)) {
      return 'Use only letters, numbers, spaces, dots, dashes or underscores.';
    }
    if (ContactFilter.containsContactDetails(alias) ||
        RegExp(r'[0-9]{7,}').hasMatch(alias)) {
      return ContactFilter.kindMessage;
    }
    if (ContentFilter.isDisrespectful(alias)) {
      return 'Please choose a kinder alias.';
    }
    if (_containsOwnName(alias, email: email, displayName: displayName)) {
      return 'Please do not use your real name or email in your alias.';
    }
    if (_fullName.hasMatch(alias)) {
      return 'That looks like a real name. Try a nickname, like moonreader '
          'or calm_kitten.';
    }
    return null;
  }

  static String? bio(String raw) {
    final bio = raw.trim();
    if (bio.length > 120) return 'Keep it to 120 characters.';
    if (ContactFilter.containsContactDetails(bio)) {
      return ContactFilter.kindMessage;
    }
    if (ContentFilter.isDisrespectful(bio)) {
      return 'Please keep your bio kind.';
    }
    return null;
  }

  /// Words (3+ letters) from her email name or Google display name.
  static bool _containsOwnName(
    String alias, {
    String? email,
    String? displayName,
  }) {
    final words = <String>{
      if (email != null)
        ...email.split('@').first.toLowerCase().split(RegExp('[^a-z]+')),
      if (displayName != null)
        ...displayName.toLowerCase().split(RegExp('[^a-z]+')),
    }.where((w) => w.length >= 3);
    final lower = alias.toLowerCase();
    return words.any(lower.contains);
  }
}
