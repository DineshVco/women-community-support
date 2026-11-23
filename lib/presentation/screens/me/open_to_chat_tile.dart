import 'package:flutter/cupertino.dart';

import '../../../core/constants/connect.dart';
import '../../../data/models/chat_profile.dart';
import '../../widgets/ios.dart';
import '../../../core/theme/app_icons.dart';

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

  /// Connect is not built yet, so this promises nothing more than what will
  /// happen when it arrives. "Open to chat" stays off by default.
  static const String explanation =
      'When Connect arrives, other women will see your chat alias and '
      'avatar, never your posts.';

  /// The waiting note, or null when there is nothing to wait for.
  static String? noteFor({
    required ChatProfile? profile,
    required DateTime? joinedAt,
    DateTime? now,
  }) {
    final isOpen = profile?.open ?? false;
    final readyAt = joinedAt?.add(ConnectOptions.openCooldown);
    final current = now ?? DateTime.now();
    final waiting = readyAt == null || current.isBefore(readyAt);
    if (profile == null) return 'Set up your chat profile first.';
    if (!isOpen && waiting) {
      if (readyAt == null) {
        return 'Getting your account ready. Try again in a moment.';
      }
      final hours = (readyAt.difference(current).inMinutes / 60).ceil();
      return 'New accounts wait a day before opening, to keep Connect safe. '
          'You can turn this on in about $hours '
          '${hours == 1 ? 'hour' : 'hours'}.';
    }
    return null;
  }

  /// The "Open to chat" row with its switch.
  static GroupedRow rowFor({
    required ChatProfile? profile,
    required DateTime? joinedAt,
    required ValueChanged<bool> onChanged,
    bool busy = false,
    DateTime? now,
    String? subtitle,
  }) {
    final isOpen = profile?.open ?? false;
    final readyAt = joinedAt?.add(ConnectOptions.openCooldown);
    final current = now ?? DateTime.now();
    final waiting = readyAt == null || current.isBefore(readyAt);
    final canChange = profile != null && !busy && (isOpen || !waiting);
    return GroupedRow(
      icon: AppIcons.chat,
      title: 'Open to chat',
      subtitle: subtitle,
      trailing: LoomaSwitch(
        value: isOpen,
        onChanged: canChange ? onChanged : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = noteFor(profile: profile, joinedAt: joinedAt, now: now);
    return GroupedSection(
      footer: note == null ? explanation : '$explanation\n\n$note',
      children: [
        rowFor(
          profile: profile,
          joinedAt: joinedAt,
          onChanged: onChanged,
          busy: busy,
          now: now,
        ),
      ],
    );
  }
}
