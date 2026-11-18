class Helpline {
  const Helpline({
    required this.name,
    required this.number,
    required this.description,
  });

  final String name;
  final String number;
  final String description;
}

/// Helplines grouped by what she needs.
class HelplineGroup {
  const HelplineGroup({
    required this.title,
    required this.lines,
    this.lastChecked,
  });

  final String title;
  final List<Helpline> lines;

  /// The day every number in this group was confirmed on the organisation's
  /// official website. Null = not confirmed yet (the app says so honestly).
  final DateTime? lastChecked;
}

/// IMPORTANT: confirm every number on the organisation's official website
/// before the demo. Numbers change, and this app must never show a wrong one.
/// After checking a group, set its `lastChecked`, e.g. DateTime(2026, 11, 18).
/// Do not add opening hours unless the official website states them.
class Helplines {
  Helplines._();

  static const Helpline emergency = Helpline(
    name: 'Emergency',
    number: '999',
    description:
        'Police, ambulance and fire. Use this if you are in danger now.',
  );

  static const Helpline befriendersKL = Helpline(
    name: 'Befrienders Kuala Lumpur',
    number: '03-7627 2929',
    description:
        'Emotional support, including if you are having thoughts of suicide.',
  );

  static const Helpline talianKasih = Helpline(
    name: 'Talian Kasih',
    number: '15999',
    description: 'Government helpline for abuse and welfare cases.',
  );

  static const Helpline wao = Helpline(
    name: 'Women’s Aid Organisation (WAO)',
    number: '03-3000 8858',
    description: 'Support for women facing abuse or violence.',
  );

  // final, not const: DateTime(...) cannot be const.
  static final List<HelplineGroup> groups = [
    HelplineGroup(
      title: 'Talk to someone now',
      lines: [befriendersKL, talianKasih],
      lastChecked: null,
    ),
    HelplineGroup(
      title: 'Women and family support',
      lines: [wao],
      lastChecked: null,
    ),
  ];

  /// Every non-emergency line, in page order.
  static List<Helpline> get support => [
    for (final group in groups) ...group.lines,
  ];
}
