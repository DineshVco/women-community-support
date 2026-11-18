/// Creates the random display name a member gets inside one discussion.
///
/// The alias depends on (user id + post id), so:
///  * the same person keeps the same alias for the whole thread, and
///  * the same person gets a DIFFERENT alias in every other thread, which
///    stops anyone linking their posts together.
///
/// The hash is deliberately small so it gives the same result on Android,
/// iOS and web (web integers lose precision above 2^53).
class AliasGenerator {
  AliasGenerator._();

  static const List<String> _adjectives = [
    'Quiet', 'Gentle', 'Brave', 'Calm', 'Bright', 'Kind', 'Steady', 'Warm',
    'Wise', 'Soft', 'Bold', 'Honest', 'Patient', 'Hopeful', 'Curious',
    'Sunny', 'Humble', 'Swift', 'Clever', 'Lively', 'Mellow', 'Noble',
    'Radiant', 'Serene', 'Sincere', 'Tender', 'Thoughtful', 'Vivid', 'Witty',
    'Graceful', 'Fearless', 'Cheerful', 'Peaceful', 'Resilient', 'Earnest',
    'Playful', 'Candid', 'Daring', 'Faithful', 'Genuine',
  ];

  static const List<String> _nouns = [
    'Fox', 'Heron', 'Orchid', 'Tiger', 'Hornbill', 'Otter', 'Jasmine',
    'Gecko', 'Firefly', 'Lotus', 'Kingfisher', 'Deer', 'Sparrow', 'Hibiscus',
    'Turtle', 'Egret', 'Bamboo', 'Dolphin', 'Swallow', 'Pangolin', 'Mynah',
    'Frangipani', 'Sunbird', 'Fern', 'Tapir', 'Mangrove', 'Magpie', 'Cicada',
    'Dragonfly', 'Moth', 'Ginger', 'Pandan', 'Lemongrass', 'Rambutan',
    'Starling', 'Langur', 'Cockatoo', 'Mudskipper', 'Butterfly', 'Monsoon',
  ];

  static String forThread({required String uid, required String postId}) {
    final hash = _hash('$uid:$postId');
    final adjective = _adjectives[hash % _adjectives.length];
    final noun = _nouns[(hash ~/ _adjectives.length) % _nouns.length];
    return '$adjective $noun';
  }

  static int _hash(String input) {
    var hash = 5381;
    for (final unit in input.codeUnits) {
      hash = ((hash * 33) ^ unit) & 0x7FFFFFFF;
    }
    return hash;
  }
}
