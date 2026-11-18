import 'package:flutter/cupertino.dart';

import '../../../core/constants/connect.dart';
import '../../../data/models/chat_profile.dart';
import '../../widgets/ios.dart';

/// The "Open to chat" switch with its plain-words explanation.
///
/// Off until she has a chat profile, and (for turning it on) until her
/// account is 24 hours old. Turning it off always works.
class OpenToChatTile extends StatelessWidget {
  const OpenToChatTile({
    super.key,
    required this.profile,
    required this.joinedAt,
    required this.onChanged,
    this.busy = false,
    this.now,
  });

  final ChatProfile? profile;

  /// When the account was created (users/{uid}.createdAt). Null while it is
  /// being recorded.
  final DateTime? joinedAt;

  final ValueChanged<bool> onChanged;
  final bool busy;

  /// For tests. Defaults to the current time.
  final DateTime? now;

  static const String explanation =
      'Other women can see your alias, avatar, interests and bio. Never '
      'your name, email or posts.';

  @override
  Widget build(BuildContext context) {
    final isOpen = profile?.open ?? false;
    final readyAt = joinedAt?.add(ConnectOptions.openCooldown);
    final current = now ?? DateTime.now();
    final waiting = readyAt == null || current.isBefore(readyAt);
    final canChange = profile != null && !busy && (isOpen || !waiting);

    String? note;
    if (profile == null) {
      note = 'Set up your chat profile first.';
    } else if (!isOpen && waiting) {
      if (readyAt == null) {
        note = 'Getting your account ready. Try again in a moment.';
      } else {
        final hours = (readyAt.difference(current).inMinutes / 60).ceil();
        note =
            'New accounts wait a day before opening, to keep Connect safe. '
            'You can turn this on in about $hours '
            '${hours == 1 ? 'hour' : 'hours'}.';
      }
    }

    return GroupedSection(
      footer: note == null ? explanation : '$explanation\n\n$note',
      children: [
        GroupedRow(
          icon: CupertinoIcons.chat_bubble,
          title: 'Open to chat',
          trailing: LoomaSwitch(
            value: isOpen,
            onChanged: canChange ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
