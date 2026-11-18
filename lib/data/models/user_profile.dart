import 'package:cloud_firestore/cloud_firestore.dart';

/// The private `users/{uid}` document. Only its owner can read it.
///
/// It holds as little as possible: the women-only confirmation, the birth
/// YEAR (never the full date) and when the account joined. Nothing here is
/// ever shown to anyone.
class UserProfile {
  const UserProfile({this.isWoman = false, this.birthYear, this.createdAt});

  /// The person confirmed "I am a woman". This is a self-confirmation,
  /// not proof.
  final bool isWoman;

  /// Saved only after the age check passed.
  final int? birthYear;

  /// Server time of the first sign-up step. Used for the 24 hour wait
  /// before "Open to chat". Older accounts get it the first time they open
  /// the Me tab.
  final DateTime? createdAt;

  /// Both sign-up steps are done, so the app can open.
  bool get isComplete => isWoman && birthYear != null;

  factory UserProfile.fromMap(Map<String, dynamic>? data) {
    final created = data?['createdAt'];
    return UserProfile(
      isWoman: data?['isWoman'] == true,
      birthYear: (data?['birthYear'] as num?)?.toInt(),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
