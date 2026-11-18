import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Creates the random display name a member gets inside one discussion.
///
/// The alias is HMAC-SHA256(secret key, post id), where the secret key is a
/// random 256-bit value stored in her private users/{uid} document (only she
/// can read it). So:
///  * the same person keeps the same alias for the whole thread,
///  * she gets a DIFFERENT alias in every other thread, and
///  * nobody else can work out her aliases, even if they know her user id.
///    (The old formula used the uid alone, which anyone could repeat.)
///
/// Posts and replies store their alias, so older ones keep showing the alias
/// they were written with.
class AliasGenerator {
  AliasGenerator._();

  static const List<String> _adjectives = [
    'Quiet',
    'Gentle',
    'Brave',
    'Calm',
    'Bright',
    'Kind',
    'Steady',
    'Warm',
    'Wise',
    'Soft',
    'Bold',
    'Honest',
    'Patient',
    'Hopeful',
    'Curious',
    'Sunny',
    'Humble',
    'Swift',
    'Clever',
    'Lively',
    'Mellow',
    'Noble',
    'Radiant',
    'Serene',
    'Sincere',
    'Tender',
    'Thoughtful',
    'Vivid',
    'Witty',
    'Graceful',
    'Fearless',
    'Cheerful',
    'Peaceful',
    'Resilient',
    'Earnest',
    'Playful',
    'Candid',
    'Daring',
    'Faithful',
    'Genuine',
  ];

  static const List<String> _nouns = [
    'Fox',
    'Heron',
    'Orchid',
    'Tiger',
    'Hornbill',
    'Otter',
    'Jasmine',
    'Gecko',
    'Firefly',
    'Lotus',
    'Kingfisher',
    'Deer',
    'Sparrow',
    'Hibiscus',
    'Turtle',
    'Egret',
    'Bamboo',
    'Dolphin',
    'Swallow',
    'Pangolin',
    'Mynah',
    'Frangipani',
    'Sunbird',
    'Fern',
    'Tapir',
    'Mangrove',
    'Magpie',
    'Cicada',
    'Dragonfly',
    'Moth',
    'Ginger',
    'Pandan',
    'Lemongrass',
    'Rambutan',
    'Starling',
    'Langur',
    'Cockatoo',
    'Mudskipper',
    'Butterfly',
    'Monsoon',
  ];

  /// [key]: her secret alias key. [postId]: the discussion.
  static String forThread({required String key, required String postId}) {
    final digest =
        Hmac(sha256, utf8.encode(key)).convert(utf8.encode(postId)).bytes;
    // First 4 bytes as a number (stays below 2^32, safe on the web too).
    final n =
        (digest[0] << 24 | digest[1] << 16 | digest[2] << 8 | digest[3]) >>> 0;
    final adjective = _adjectives[n % _adjectives.length];
    final noun = _nouns[(n ~/ _adjectives.length) % _nouns.length];
    return '$adjective $noun';
  }

  /// A new secret alias key: 32 random bytes as 64 hex characters.
  static String newKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// The shape firestore.rules accepts for a key.
  static final RegExp keyPattern = RegExp(r'^[0-9a-f]{64}$');
}
