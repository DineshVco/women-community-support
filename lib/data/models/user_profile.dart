import 'package:cloud_firestore/cloud_firestore.dart';

/// The private `users/{uid}` document. Only its owner can read it.
///
/// It holds as little as possible: the women-only confirmation, the birth
/// YEAR (never the full date), when the account joined and, if she chose
/// one, the name Looma greets her with. Nothing here is ever shown to
/// anyone else.
class UserProfile {
  const UserProfile({
    this.isWoman = false,
    this.birthYear,
    this.createdAt,
    this.callName,
  });

  /// The person confirmed "I am a woman". This is a self-confirmation,
  /// not proof.
  final bool isWoman;

  /// Saved only after the age check passed.
  final int? birthYear;

  /// Server time of the first sign-up step. Used for the 24 hour wait
  /// before "Open to chat". Older accounts get it the first time they open
  /// the Me tab.
  final DateTime? createdAt;

  /// "What should we call you?": a first name or nickname for the Discuss
  /// greeting. Only she sees it. Null if she skipped it.
  final String? callName;

  /// Both sign-up steps are done, so the app can open.
  bool get isComplete => isWoman && birthYear != null;

  factory UserProfile.fromMap(Map<String, dynamic>? data) {
    final created = data?['createdAt'];
    return UserProfile(
      isWoman: data?['isWoman'] == true,
      birthYear: (data?['birthYear'] as num?)?.toInt(),
      createdAt: created is Timestamp ? created.toDate() : null,
      callName: data?['callName'] as String?,
    );
  }
}
