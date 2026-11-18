import 'package:cloud_firestore/cloud_firestore.dart';

/// A member's chat identity for Looma Connect: `chatProfiles/{chatId}`.
///
/// It is separate from post aliases. Nothing here links to her posts,
/// replies, name or email. Other members can read it only while [open].
class ChatProfile {
  const ChatProfile({
    required this.alias,
    required this.avatarId,
    this.bio = '',
    this.interests = const [],
    this.lookingFor = const [],
    this.open = false,
    this.createdAt,
    this.updatedAt,
  });

  final String alias;
  final String avatarId;
  final String bio;
  final List<String> interests;
  final List<String> lookingFor;

  /// "Open to chat": listed in the Connect hub.
  final bool open;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChatProfile.fromMap(Map<String, dynamic> data) {
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];
    DateTime? time(Object? value) => value is Timestamp ? value.toDate() : null;

    return ChatProfile(
      alias: data['alias'] as String? ?? '',
      avatarId: data['avatarId'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      interests: strings(data['interests']),
      lookingFor: strings(data['lookingFor']),
      open: data['open'] == true,
      createdAt: time(data['createdAt']),
      updatedAt: time(data['updatedAt']),
    );
  }

  ChatProfile copyWith({
    String? alias,
    String? avatarId,
    String? bio,
    List<String>? interests,
    List<String>? lookingFor,
    bool? open,
  }) {
    return ChatProfile(
      alias: alias ?? this.alias,
      avatarId: avatarId ?? this.avatarId,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      lookingFor: lookingFor ?? this.lookingFor,
      open: open ?? this.open,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
