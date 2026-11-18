/// Fixed lists and limits for chat profiles (Looma Connect).
///
/// firestore.rules has the SAME lists and numbers. Change both together.
class ConnectOptions {
  ConnectOptions._();

  static const int aliasMin = 3;
  static const int aliasMax = 20;
  static const int bioMax = 120;
  static const int maxInterests = 5;
  static const int maxLookingFor = 2;

  /// New accounts wait this long before "Open to chat" can be turned on.
  static const Duration openCooldown = Duration(hours: 24);

  static const List<ConnectOption> interests = [
    ConnectOption('health', 'Health'),
    ConnectOption('study', 'Study'),
    ConnectOption('career', 'Career'),
    ConnectOption('safety', 'Safety'),
    ConnectOption('family', 'Family'),
    ConnectOption('money', 'Money'),
    ConnectOption('friendship', 'Friendship'),
    ConnectOption('mental_wellbeing', 'Mental wellbeing'),
    ConnectOption('new_in_town', 'New in town'),
    ConnectOption('hobbies', 'Hobbies'),
  ];

  static const List<ConnectOption> lookingFor = [
    ConnectOption('talk', 'Someone to talk to'),
    ConnectOption('study_buddy', 'Study buddy'),
    ConnectOption('career_advice', 'Career advice'),
    ConnectOption('friends', 'Just friends'),
  ];

  static String labelFor(List<ConnectOption> options, String id) =>
      options
          .firstWhere((o) => o.id == id, orElse: () => ConnectOption(id, id))
          .label;
}

class ConnectOption {
  const ConnectOption(this.id, this.label);

  /// Stored in Firestore.
  final String id;

  /// Shown in the app.
  final String label;
}
